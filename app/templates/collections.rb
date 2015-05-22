class Collections
  include Templatable

  def body
    Jbuilder.encode do |json|
      json.template "*-#{I14y::APP_NAME}-collections-*"
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
      string_fields_template(json, "not_analyzed")
    end
  end
end