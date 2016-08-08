class DocumentSearch
  NO_HITS = { "hits" => { "total" => 0, "hits" => [] }}

  def initialize(options)
    @options = options
    @options[:offset] ||= 0
  end

  def search
    i14y_search_results = execute_client_search
    if i14y_search_results.total.zero? && i14y_search_results.suggestion.present?
      suggestion = i14y_search_results.suggestion
      @options[:query] = suggestion['text']
      i14y_search_results = execute_client_search
      i14y_search_results.override_suggestion(suggestion) if i14y_search_results.total > 0
    end
    i14y_search_results
  rescue Exception => e
    Rails.logger.error "Problem in DocumentSearch#search(): #{e}
    #{e.backtrace}"
    DocumentSearchResults.new(NO_HITS)
  end

  private

  def execute_client_search
    query = DocumentQuery.new(@options)
    params = { index: document_indexes, body: query.body, from: @options[:offset], size: @options[:size] }
    result = Elasticsearch::Persistence.client.search(params)
    DocumentSearchResults.new(result, @options[:offset])
  end

  def document_indexes
    @options[:handles].map { |collection_handle| Document.index_namespace(collection_handle) }
  end

end
