# frozen_string_literal: true

class DocumentQuery
  include Elasticsearch::DSL

  HIGHLIGHT_OPTIONS = {
    pre_tags: ["\ue000"],
    post_tags: ["\ue001"]
  }.freeze

  DEFAULT_STOPWORDS = %w[
    a an and are as at be but by for if in into is it
    no not of on or such that the their then there these
    they this to was will with
  ].freeze

  AGGREGATION_FIELDS = %i[audience
                          content_type
                          mime_type
                          searchgov_custom1
                          searchgov_custom2
                          searchgov_custom3
                          tags].freeze

  DATE_AGGREGATION_FIELDS = %i[created
                               changed].freeze

  attr_reader :audience,
              :content_type,
              :date_range,
              :excluded_sites,
              :ignore_tags,
              :included_sites,
              :language,
              :mime_type,
              :searchgov_custom1,
              :searchgov_custom2,
              :searchgov_custom3,
              :site_filters,
              :tags
  attr_accessor :query,
                :search

  def initialize(options)
    @options = options
    @date_range = { gte: @options[:min_timestamp], lt: @options[:max_timestamp] }
    @excluded_sites = []
    @ignore_tags = options[:ignore_tags]
    @included_sites = []
    @search = Search.new
    parse_filters(options)
    parse_query(options[:query]) if options[:query]
  end

  def body
    search.source source_fields
    search.sort { by :changed, order: 'desc' } if @options[:sort_by_date]
    if query.present?
      query_options
    end
    build_search_query
    search.explain true if Rails.logger.debug? # scoring details
    search
  end

  def query_options
    set_highlight_options
    search.suggest(:suggestion, suggestion_hash)
    AGGREGATION_FIELDS.each do |facet|
      search.aggregation(facet, aggregation_hash(facet))
    end
    DATE_AGGREGATION_FIELDS.each do |date_facet|
      search.aggregation(date_facet, date_aggregation_hash(date_facet))
    end
  end

  def full_text_fields
    @full_text_fields ||= begin
      %w[title description content].index_with { |field| suffixed(field) }
    end
  end

  def common_terms_hash
    {
      query: query,
      cutoff_frequency: 0.05,
      minimum_should_match: { low_freq: '3<90%', high_freq: '2<90%' }
    }
  end

  def source_fields
    default_fields = %w[title path created changed]
    fields = (@options[:include] || default_fields).push('language')
    fields.map { |field| full_text_fields[field] || field }
  end

  def timestamp_filters_present?
    @options[:min_timestamp].present? or @options[:max_timestamp].present?
  end

  def boosted_fields
    full_text_fields.values.map do |field|
      if /title/ === field
        "#{field}^2"
      elsif /description/ === field
        "#{field}^1.5"
      else
        field.to_s
      end
    end
  end

  def functions
    [
      # Prefer more recent documents
      {
        gauss: {
          changed: { origin: 'now', scale: '1825d', offset: '30d', decay: 0.3 }
        }
      },

      # Avoid pdfs, etc.
      {
        filter: {
          terms: {
            extension: %w[doc docx pdf ppt pptx xls xlsx]
          }
        },
        weight: '.75'
      },

      # Prefer documents that have been clicked more often
      {
        field_value_factor: {
          field: 'click_count', modifier: 'log1p', factor: 2, missing: 1
        }
      }
    ]
  end

  private

  def suffixed(field)
    [field, language].compact.join('_')
  end

  def parse_query(query)
    site_params_parser = QueryParser.new(query)
    @site_filters = site_params_parser.site_filters
    @included_sites = @site_filters[:included_sites]
    @excluded_sites = @site_filters[:excluded_sites]
    @query = site_params_parser.stripped_query
  end

  def parse_filters(options)
    @audience = options[:audience]
    @content_type = options[:content_type]
    @language = options[:language] || 'en'
    @mime_type = options[:mime_type]
    @searchgov_custom1 = options[:searchgov_custom1]
    @searchgov_custom2 = options[:searchgov_custom2]
    @searchgov_custom3 = options[:searchgov_custom3]
    @tags = options[:tags]
  end

  def set_highlight_options
    highlight_fields = highlight_fields_hash
    search.highlight do
      pre_tags HIGHLIGHT_OPTIONS[:pre_tags]
      post_tags HIGHLIGHT_OPTIONS[:post_tags]
      fields highlight_fields
    end
  end

  def aggregation_hash(facet_field)
    {
      terms: {
        field: facet_field
      }
    }
  end

  def date_aggregation_hash(date_facet_field)
    {
      date_range: {
        field: date_facet_field,
        format: '8M/d/u',
        ranges: [
          {
            key: 'Last Week',
            from: 'now-1w',
            to: 'now'
          },
          {
            key: 'Last Month',
            from: 'now-1M',
            to: 'now'
          },
          {
            key: 'Last Year',
            from: 'now-12M',
            to: 'now'
          }
        ]
      }
    }
  end

  def suggestion_hash
    { text: query_without_stopwords,
      phrase: {
        field: 'bigrams',
        size: 1,
        highlight: suggestion_highlight,
        collate: { query: { source: { multi_match: { query: '{{suggestion}}',
                                                     type: 'phrase',
                                                     fields: "*_#{language}" } } } }
      } }
  end

  def highlight_fields_hash
    {
      full_text_fields['title'] => {
        number_of_fragments: 0,
        type: 'fvh'
      },
      full_text_fields['description'] => {
        fragment_size: 75,
        number_of_fragments: 2,
        type: 'fvh'
      },
      full_text_fields['content'] => {
        fragment_size: 75,
        number_of_fragments: 2,
        type: 'fvh'
      }
    }
  end

  def suggestion_highlight
    {
      pre_tag: HIGHLIGHT_OPTIONS[:pre_tags].first,
      post_tag: HIGHLIGHT_OPTIONS[:post_tags].first
    }
  end

  # Temporary fix for https://github.com/elastic/elasticsearch/issues/34282
  def query_without_stopwords
    (query.downcase.split(/ +/) - DEFAULT_STOPWORDS).join(' ')
  end

  # Disabling length-related cops, as this method is intended to mimic the structure
  # of a complex Elasticsearch query using the Elasticsearch DSL
  # https://github.com/elastic/elasticsearch-ruby/tree/master/elasticsearch-dsl
  # rubocop:disable Metrics/MethodLength, Metrics/BlockLength
  def build_search_query
    doc_query = self

    search.query do
      function_score do
        functions doc_query.functions

        query do
          bool do
            if doc_query.query.present?
              must do
                bool do
                  # prefer bigram matches
                  should { match bigrams: { operator: 'and', query: doc_query.query } }
                  should { term  promote: true }

                  # prefer_word_form_matches
                  must do
                    bool do
                      should do
                        bool do
                          must do
                            simple_query_string do
                              query doc_query.query
                              fields doc_query.boosted_fields
                            end
                          end

                          unless doc_query.query.match(/".*"/)
                            must do
                              bool do
                                doc_query.full_text_fields.values.each do |field|
                                  should { common({ field => doc_query.common_terms_hash }) }
                                end
                              end
                            end
                          end
                        end
                      end

                      should { match basename: { operator: 'and', query: doc_query.query } }
                      should { match tags:     { operator: 'and', query: doc_query.query.downcase } }
                    end
                  end
                end
              end
            end

            filter do
              bool do
                must { term audience: doc_query.audience } if doc_query.audience.present?
                must { term content_type: doc_query.content_type } if doc_query.content_type.present?
                must { term language: doc_query.language } if doc_query.language.present?
                must { term mime_type: doc_query.mime_type } if doc_query.mime_type.present?

                if doc_query.included_sites.any?
                  minimum_should_match 1

                  doc_query.included_sites.each do |site_filter|
                    should do
                      bool do
                        must { term domain_name: site_filter.domain_name }
                        must { term url_path: site_filter.url_path } if site_filter.url_path.present?
                      end
                    end
                  end
                end

                doc_query.searchgov_custom1.each { |sgc1| must { term searchgov_custom1: sgc1 } } if doc_query.searchgov_custom1.present?
                doc_query.searchgov_custom2.each { |sgc2| must { term searchgov_custom2: sgc2 } } if doc_query.searchgov_custom2.present?
                doc_query.searchgov_custom3.each { |sgc3| must { term searchgov_custom3: sgc3 } } if doc_query.searchgov_custom3.present?
                doc_query.tags.each { |tag| must { term tags: tag } } if doc_query.tags.present?

                must { range changed: doc_query.date_range } if doc_query.timestamp_filters_present?

                if doc_query.ignore_tags.present?
                  must_not do
                    terms tags: doc_query.ignore_tags
                  end
                end

                doc_query.excluded_sites.each do |site_filter|
                  if site_filter.url_path.present?
                    must_not { regexp path: { value: "https?:\/\/#{site_filter.domain_name}#{site_filter.url_path}/.*" } }
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
  end
  # rubocop:enable Metrics/MethodLength, Metrics/BlockLength
end
