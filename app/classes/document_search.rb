class DocumentSearch
  NO_HITS = { "hits" => { "total" => 0, "hits" => [] }}

  attr_reader :doc_query, :offset, :size, :indices

  def initialize(options)
    @offset = options[:offset] || 0
    @size = options[:size]
    @doc_query = DocumentQuery.new(options)
    @indices = options[:handles].map { |handle| Document.index_namespace(handle) }
  end

  def search
    i14y_search_results = execute_client_search
    if i14y_search_results.total.zero? && i14y_search_results.suggestion.present?
      suggestion = i14y_search_results.suggestion
      doc_query.query = suggestion['text']
      i14y_search_results = execute_client_search
      i14y_search_results.override_suggestion(suggestion) if i14y_search_results.results.present?
    end
    i14y_search_results
  rescue StandardError => e
    Rails.logger.error "Problem in DocumentSearch#search(): #{e}
    #{e.backtrace}"
    DocumentSearchResults.new(NO_HITS)
  end

  private

  def execute_client_search
    params = { index: indices, body: doc_query.body, from: offset, size: size }
    Rails.logger.debug "Query: *****\n#{doc_query.body.to_json}\n*****"
    result = Elasticsearch::Persistence.client.search(params)
    DocumentSearchResults.new(result, offset)
  end
end
