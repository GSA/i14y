module Serde
  def self.serialize_hash(hash, language, language_field_keys)
    language_field_keys.each do |key|
      value = hash[key.to_sym]
      if value.present?
        sanitized_value = Sanitize.fragment(value).strip.squish
        hash.store("#{key}_#{language}", sanitized_value)
        hash[key] = sanitized_value
      end
    end
    hash.merge!(uri_params_hash(hash[:path])) if hash[:path].present?
    hash[:tags] = hash[:tags].extract_tags if hash[:tags].present?
    hash
  end

  def self.deserialize_hash(hash, language, language_field_keys)
    derivative_language_fields = language_field_keys.collect { |key| "#{key}_#{language}" }
    misc_fields = %w(basename url_path domain_name bigrams)
    hash.except(*(derivative_language_fields + misc_fields))
  end

  private

  def self.uri_params_hash(path)
    hash = {}
    uri = URI.parse(path)
    hash[:basename] = File.basename(uri.path, '.*')
    hash[:url_path] = uri.path
    hash[:domain_name] = uri.host
    hash
  end
end