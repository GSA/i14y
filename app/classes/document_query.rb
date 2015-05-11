class DocumentQuery
  INCLUDED_SOURCE_FIELDS = %w(title description content path created updated promote language)
  FULLTEXT_FIELDS = %w(title description content)
  BIGRAM_FIELDS = FULLTEXT_FIELDS.map { |field| "#{field}_bigrams" }

  HIGHLIGHT_OPTIONS = {
    pre_tags: ["\ue000"],
    post_tags: ["\ue001"]
  }

  def initialize(options)
    @options = options
    site_params_parser = QueryParser.new(options[:query])
    @site_filters = site_params_parser.site_filters
    @options[:query] = site_params_parser.remaining_query
  end

  def body
    Jbuilder.encode do |json|
      source_fields(json)
      filtered_query(json)
      highlight(json)
    end
  end

  def source_fields(json)
    json._source do
      json.include INCLUDED_SOURCE_FIELDS
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
        json.must do
          json.child! do
            json.term do
              json.language @options[:language]
            end
          end
          filter_on_sites(json) if @site_filters.any?
        end
      end
    end
  end

  def filter_on_sites(json)
    json.child! do
      json.bool do
        json.set! :should do
          json.array!(@site_filters) do |site_filter|
            filter_on_site(json, site_filter)
          end
        end
      end
    end
  end

  def filter_on_site(json, site_filter)
    json.bool do
      json.must do
        json.child! do
          json.term do
            json.domain_name site_filter.domain_name
          end
        end
        json.child! do
          json.term do
            json.url_path site_filter.url_path
          end
        end if site_filter.url_path.present?
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
    json.child! do
      json.multi_match do
        json.query @options[:query]
        json.fields BIGRAM_FIELDS
      end
    end
  end

  def prefer_word_form_matches(json)
    json.child! do
      json.multi_match do
        json.query @options[:query]
        json.fields FULLTEXT_FIELDS
      end
    end
  end

  def url_basename_matches(json)
    json.match do
      json.basename do
        json.query @options[:query]
        json.operator :and
      end
    end
  end

  def broadest_match(json)
    json.bool do
      json.set! :should do
        FULLTEXT_FIELDS.each do |field|
          json.child! do
            common_terms(json, field)
          end
        end
        json.child! do
          url_basename_matches(json)
        end
      end
    end
  end

  def common_terms(json, field)
    json.common do
      json.set! "#{field}_#{@options[:language]}" do
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
      json.set! "title_#{@options[:language]}", { number_of_fragments: 0 }
      json.set! "description_#{@options[:language]}", { fragment_size: 75, number_of_fragments: 2 }
      json.set! "content_#{@options[:language]}", { fragment_size: 75, number_of_fragments: 2 }
    end
  end

end