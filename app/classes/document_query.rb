class DocumentQuery
  INCLUDED_SOURCE_FIELDS = %w(title description content path created updated promote language tags changed updated_at)
  FULLTEXT_FIELDS = %w(title description content)

  HIGHLIGHT_OPTIONS = {
    pre_tags: ["\ue000"],
    post_tags: ["\ue001"]
  }

  def initialize(options)
    @options = options
    if options[:query]
      site_params_parser = QueryParser.new(options[:query])
      @site_filters = site_params_parser.site_filters
      @options[:query] = site_params_parser.remaining_query
    end
  end

  def body
    Jbuilder.encode do |json|
      source_fields(json)
      sort_by_date(json) if @options[:sort_by_date]
      filtered_query(json)
      if @options[:query].present?
        highlight(json)
        suggest(json)
      end
    end
  end

  def sort_by_date(json)
    json.sort do
      json.created do
        json.order :desc
      end
    end
  end

  def source_fields(json)
    json._source do
      json.include @options[:include] || INCLUDED_SOURCE_FIELDS
    end
  end

  def filtered_query(json)
    json.query do
      json.filtered do
        filtered_query_query(json) if @options[:query].present?
        filtered_query_filter(json)
      end
    end
  end

  def filtered_query_filter(json)
    json.filter do
      json.bool do
        musts(json)
        must_nots(json)
      end
    end
  end

  def must_nots(json)
    json.must_not do
      filter_on_tags(json, @options[:ignore_tags]) if @options[:ignore_tags].present?
      if @site_filters[:excluded_sites].any?
        @site_filters[:excluded_sites].each do |site_filter|
          child_term_filter(json, :domain_name, site_filter.domain_name)
          child_term_filter(json, :url_path, site_filter.url_path) if site_filter.url_path.present?
        end
      end
    end
  end

  def musts(json)
    json.must do
      filter_on_language(json) if @options[:language].present?
      filter_on_sites(json) if @site_filters.present?
      filter_on_tags(json, @options[:tags], :and) if @options[:tags].present?
      filter_on_time(json) if timestamp_filters_present?
    end
  end

  def filter_on_language(json)
    child_term_filter(json, :language, @options[:language])
  end

  def filter_on_time(json)
    json.child! do
      json.range do
        json.set! "created" do
          json.gte @options[:min_timestamp] if @options[:min_timestamp].present?
          json.lt @options[:max_timestamp] if @options[:max_timestamp].present?
        end
      end
    end
  end

  def filter_on_tags(json, tags, execution = :plain)
    json.child! do
      json.terms do
        json.tags tags
        json.execution execution
      end
    end
  end

  def filter_on_sites(json)
    json.child! do
      json.bool do
        json.set! :should do
          json.array!(@site_filters[:included_sites]) do |site_filter|
            filter_on_site(json, site_filter)
          end
        end
      end
    end
  end

  def filter_on_site(json, site_filter)
    json.bool do
      json.must do
        child_term_filter(json, :domain_name, site_filter.domain_name)
        child_term_filter(json, :url_path, site_filter.url_path) if site_filter.url_path.present?
      end
    end
  end

  def filtered_query_query(json)
    json.query do
      json.bool do
        json.must do
          broadest_match(json)
        end
        json.set! :should do
          prefer_bigram_matches(json)
          prefer_word_form_matches(json)
        end
      end
    end
  end

  def prefer_bigram_matches(json)
    child_match(json, :bigrams, @options[:query])
  end

  def prefer_word_form_matches(json)
    json.child! do
      json.multi_match do
        json.query @options[:query]
        json.fields FULLTEXT_FIELDS
      end
    end
  end

  def broadest_match(json)
    json.bool do
      json.set! :should do
        common_terms_matches(json)
        basename_matches(json)
        tag_matches(json)
      end
    end
  end

  def common_terms_matches(json)
    FULLTEXT_FIELDS.each do |field|
      json.child! do
        common_terms(json, field)
      end
    end
  end

  def basename_matches(json)
    child_match(json, :basename, @options[:query])
  end

  def tag_matches(json)
    child_match(json, :tags, @options[:query].downcase)
  end

  def common_terms(json, field)
    json.common do
      json.set! [field, @options[:language]].compact.join('_') do
        json.query @options[:query]
        json.cutoff_frequency 0.05
        json.minimum_should_match do
          json.low_freq "3<90%"
          json.high_freq "2<90%"
        end
      end
    end
  end

  def highlight(json)
    json.highlight do
      json.pre_tags HIGHLIGHT_OPTIONS[:pre_tags]
      json.post_tags HIGHLIGHT_OPTIONS[:post_tags]
      highlight_fields(json)
    end
  end

  def highlight_fields(json)
    json.fields do
      json.set! ['title',@options[:language]].compact.join('_'), { number_of_fragments: 0 }
      json.set! ['description',@options[:language]].compact.join('_'), { number_of_fragments: 0 }
      json.set! ['content',@options[:language]].compact.join('_'), { number_of_fragments: 0 }

    end
  end

  def suggest(json)
    json.suggest do
      json.text @options[:query]
      json.suggestion do
        phrase_suggestion(json)
      end
    end
  end

  def phrase_suggestion(json)
    json.phrase do
      json.field "bigrams"
      json.size 1
      suggestion_highlight(json)
      collate(json)
    end
  end

  def suggestion_highlight(json)
    json.highlight do
      json.pre_tag HIGHLIGHT_OPTIONS[:pre_tags].first
      json.post_tag HIGHLIGHT_OPTIONS[:post_tags].first
    end
  end

  def collate(json)
    json.collate do
      json.query do
        json.multi_match do
          json.query "{{suggestion}}"
          json.type "phrase"
          json.fields "*_#{@options[:language]}"
        end
      end
    end
  end

  def timestamp_filters_present?
    @options[:min_timestamp].present? or @options[:max_timestamp].present?
  end

  private

  def child_match(json, field, query, operator = :and)
    json.child! do
      json.match do
        json.set! field do
          json.operator operator
          json.query query
        end
      end
    end if query
  end

  def child_term_filter(json, field, value)
    json.child! do
      json.term do
        json.set! field, value
      end
    end
  end

end
