class Collections
  def body
    Jbuilder.encode do |json|
      json.template "*-#{APP_NAME}-collections-*"
      json.mappings do
        json.collection do
          dynamic_templates(json)
          json._all { json.enabled false }
        end
      end
    end
  end

  def dynamic_templates(json)
    json.dynamic_templates do
      json.child! do
        json.string_fields do
          json.mapping do
            json.index "not_analyzed"
            json.type "string"
          end
          json.match_mapping_type "string"
          json.match "*"
        end
      end
    end
  end
end