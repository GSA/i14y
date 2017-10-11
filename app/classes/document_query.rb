class DocumentQuery
  include Elasticsearch::DSL
  INCLUDED_SOURCE_FIELDS = %w(title description content path created updated promote language tags changed updated_at)
  FULLTEXT_FIELDS = %w(title description content)

  HIGHLIGHT_OPTIONS = {
    pre_tags: ["\ue000"],
    post_tags: ["\ue001"]
  }

  attr_reader :language, :site_filters, :tags, :ignore_tags, :date_range,
              :included_sites, :excluded_sites
  attr_accessor :query, :search

  def initialize(options)
    @options = options
    @language = options[:language]
    @tags = options[:tags]
    @ignore_tags = options[:ignore_tags]
    @date_range = { gte: @options[:min_timestamp], lt: @options[:max_timestamp] }
    @search = Search.new
    @included_sites, @excluded_sites = [], []
    parse_query(options[:query]) if options[:query]
  end

  def body
    search.source source_fields
    search.sort { by :created, order: 'desc' } if @options[:sort_by_date]
    if query.present?
      set_highlight_options
      search.suggest(:suggestion, suggestion_hash)
    end
    build_search_query
    search.explain true if Rails.logger.level == 0 #scoring details
    search
  end

  def suggestion_hash
    { text: query,
      phrase: {
        field: 'bigrams',
        size: 1,
        highlight: suggestion_highlight,
        collate: { query: { multi_match: { query: "{{suggestion}}",
                                           type:   "phrase",
                                           fields: "*_#{language}" } }
        }
      }
    }
  end

  def full_text_fields
    FULLTEXT_FIELDS.map{ |field| [field, language].compact.join('_').to_sym }
  end

  def common_terms_hash
    {
      query: query,
      cutoff_frequency: 0.05,
      minimum_should_match: { low_freq: '3<90%', high_freq: '2<90%' },
    }
  end

  def source_fields
    @options[:include] || INCLUDED_SOURCE_FIELDS
  end

  def timestamp_filters_present?
    @options[:min_timestamp].present? or @options[:max_timestamp].present?
  end

  def boosted_fields
    full_text_fields.map do |field|
      if /title/ === field
        "#{field}^2"
      elsif /description/ === field
        "#{field}^1.5"
      else
        field.to_s
      end
    end
  end

  private

  def parse_query(query)
    site_params_parser = QueryParser.new(query)
    @site_filters = site_params_parser.site_filters
    @included_sites = @site_filters[:included_sites]
    @excluded_sites = @site_filters[:excluded_sites]
    @query = site_params_parser.stripped_query
  end

  def set_highlight_options
    highlight_fields = highlight_fields_hash
    search.highlight do
      pre_tags HIGHLIGHT_OPTIONS[:pre_tags]
      post_tags HIGHLIGHT_OPTIONS[:post_tags]
      fields highlight_fields
    end
  end

  def highlight_fields_hash
    {
      ['title',language].compact.join('_') => { number_of_fragments: 0 },
      ['description',language].compact.join('_') => { fragment_size: 75, number_of_fragments: 2 },
      ['content',language].compact.join('_') => { fragment_size: 75, number_of_fragments: 2 },
    }
  end

  def suggestion_highlight
    {
      pre_tag: HIGHLIGHT_OPTIONS[:pre_tags].first,
      post_tag: HIGHLIGHT_OPTIONS[:post_tags].first,
    }
  end

  def build_search_query
    #DSL reference: https://github.com/elastic/elasticsearch-ruby/tree/master/elasticsearch-dsl
    doc_query = self
    search.query do
      filtered do
        if doc_query.query.present?
          query do
            bool do
              must do #broadest match
                bool do
                  doc_query.full_text_fields.each do |field|
                    should { common({ field => doc_query.common_terms_hash }) }
                  end

                  should { match basename: { operator: 'and', query: doc_query.query } }
                  should { match tags:     { operator: 'and', query: doc_query.query.downcase } }
                end
              end

              #prefer bigram matches
              should { match bigrams: { operator: 'and', query: doc_query.query } }

              ##prefer_word_form_matches
              should do
                multi_match do
                  query doc_query.query
                  fields doc_query.boosted_fields
                end
              end
            end
          end

        end

        filter do
          bool do
            must { term language: doc_query.language } if doc_query.language.present?

            doc_query.included_sites.each do |site_filter|
              should do
                bool do
                  must { term domain_name: site_filter.domain_name }
                  must { term url_path: site_filter.url_path } if site_filter.url_path.present?
                end
              end
            end

            must do
              terms tags: doc_query.tags, execution: 'and' if doc_query.tags.present?
            end

            must { range created: doc_query.date_range } if doc_query.timestamp_filters_present?

            must_not do
              terms tags: doc_query.ignore_tags, execution: 'plain' if doc_query.ignore_tags.present?
            end

            doc_query.excluded_sites.each do |site_filter|
              if site_filter.url_path.present?
                must_not { query { regexp path: { value: "https?:\/\/#{site_filter.domain_name}#{site_filter.url_path}/.*" } } }
              else
                must_not { term domain_name: site_filter.domain_name }
              end
            end
          end
        end
      end
    end
  end
end
