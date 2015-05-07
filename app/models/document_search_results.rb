class DocumentSearchResults
  attr_reader :total, :offset, :results

  def initialize(result, offset = 0)
    @total = result['hits']['total']
    @offset = offset
    @results = extract_hits(result['hits']['hits'])
  end

  private

  def extract_hits(hits)
    hits.map do |hit|
      highlight = hit['highlight']
      source = hit['_source']
      if highlight.present?
        source['title'] = highlight["title_#{source['language']}"].first if highlight["title_#{source['language']}"]
        source['description'] = highlight["description_#{source['language']}"].join('...') if highlight["description_#{source['language']}"]
        source['content'] = highlight["content_#{source['language']}"].join('...') if highlight["content_#{source['language']}"]
      end
      source['created'] = DateTime.parse(source['created']).utc.to_s
      if source['updated'].present?
        source['updated'] = DateTime.parse(source['updated']).utc.to_s
      else
        source.delete('updated')
      end
      source
    end
  end

end