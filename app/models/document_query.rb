class DocumentQuery
  INCLUDED_SOURCE_FIELDS = %w(title description content path created updated promote language)

  HIGHLIGHT_OPTIONS = {
    pre_tags: ["\ue000"],
    post_tags: ["\ue001"]
  }

  def initialize(options)
    @options = options
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
        filtered_query_query(json)
        filtered_query_filter(json)
      end
    end
  end

  def filtered_query_filter(json)
    json.filter do
      json.term do
        json.language @options[:language]
      end
    end
  end

  def filtered_query_query(json)
    json.query do
      json.common do
        json.set! "title_#{@options[:language]}" do
          json.query @options[:query]
          json.cutoff_frequency 0.001
          json.minimum_should_match "85%"
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