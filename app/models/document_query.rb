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
        json.cutoff_frequency 0.001
        json.minimum_should_match "85%"
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