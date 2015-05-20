class Serde
  def self.serialize_hash(hash, language, language_field_keys)
    language_field_keys.each do |key|
      value = hash[key.to_sym]
      if value.present?
        sanitized_value = Sanitize.fragment(value).strip.squish
        hash.store("#{key}_#{language}", sanitized_value)
        hash[key] = sanitized_value
      end
    end
    uri = URI.parse(hash[:path])
    hash[:basename] = File.basename(uri.path, '.*')
    hash[:url_path] = uri.path
    hash[:domain_name] = uri.host
    hash
  end

  def self.deserialize_hash(hash, language, language_field_keys)
    derivative_language_fields = language_field_keys.collect { |key| "#{key}_#{language}" }
    misc_fields = %w(basename url_path domain_namer bigrams)
    hash.except(*(derivative_language_fields + misc_fields))
  end
end