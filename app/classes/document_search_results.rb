class DocumentSearchResults
  attr_reader :total, :offset, :results, :suggestion

  def initialize(result, offset = 0)
    @total = result['hits']['total']
    @offset = offset
    @results = extract_hits(result['hits']['hits'])
    @suggestion = extract_suggestion(result['suggest']['suggestion']) if result['suggest']
  end

  def override_suggestion(suggestion)
    @suggestion = suggestion
  end

  private

  def extract_suggestion(suggestions)
    suggestion = suggestions.first['options'].first
    suggestion.delete('score')
    suggestion
  rescue NoMethodError => e
    nil
  end

  def extract_hits(hits)
    hits.map do |hit|
      highlight = hit['highlight']
      source = hit['_source']
      if highlight.present?
        source['title'] = highlight["title_#{source['language']}"].first if highlight["title_#{source['language']}"]
        %w(description content).each do |optional_field|
          language_field = "#{optional_field}_#{source['language']}"
          source[optional_field] = highlight[language_field].join('...') if highlight[language_field]
        end
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