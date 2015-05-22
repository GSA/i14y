module Templatable
  def date(json, field)
    json.set! field do
      json.type "date"
    end
  end

  def keyword(json, field)
    json.set! field do
      json.type "string"
      json.index "not_analyzed"
    end
  end

  def string_fields_template(json, analyzer)
    json.string_fields do
      json.mapping do
        json.analyzer analyzer
        json.type "string"
      end
      json.match_mapping_type "string"
      json.match "*"
    end
  end
end
