class DocumentSearchResults
  attr_reader :total, :offset, :results, :suggestion

  def initialize(result, offset = 0)
    @total = result['hits']['total']
    @offset = offset
    @results = extract_hits(result['hits']['hits'])
    @suggestion = extract_suggestion(result['suggest'])
  end

  def override_suggestion(suggestion)
    @suggestion = suggestion
  end

  private

  def extract_suggestion(suggest)
    return unless suggest && total.zero?

    suggest['suggestion'].first['options'].first.except('score')
  rescue NoMethodError
    nil
  end

  def extract_hits(hits)
    hits.map do |hit|
      highlight = hit['highlight']
      source =  deserialized(hit)
      if highlight.present?
        source['title'] = highlight["title_#{source['language']}"].first if highlight["title_#{source['language']}"]
        %w(description content).each do |optional_field|
          language_field = "#{optional_field}_#{source['language']}"
          source[optional_field] = highlight[language_field].join('...') if highlight[language_field]
        end
      end
      %w(created_at created changed updated_at updated).each do |date|
        source[date] = Time.parse(source[date]).utc.to_s if source[date].present?
      end
      source
    end
  end

  def deserialized(hit)
    Serde.deserialize_hash(ActiveSupport::HashWithIndifferentAccess.new(hit['_source']),
                           hit['_source']['language'],
                           %i[title description content])

  end
end
