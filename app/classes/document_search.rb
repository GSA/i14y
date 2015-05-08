class DocumentSearch
  NO_HITS = { "hits" => { "total" => 0, "hits" => [] }}

  def initialize(options)
    @options = options
    @options[:offset] ||= 0
  end

  def search
    execute_client_search
  rescue Exception => e
    Rails.logger.error "Problem in DocumentSearch#search(): #{e}"
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