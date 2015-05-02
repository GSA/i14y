class LanguageSerde
  def self.serialize_hash(hash, language, language_field_keys)
    language_field_keys.each do |key|
      value = hash[key.to_sym]
      if value.present?
        hash.store("#{key}_#{language}", value)
        hash.store("#{key}_bigrams", value)
      end
    end
    hash
  end

  def self.deserialize_hash(hash, language, language_field_keys)
    derivative_language_fields = language_field_keys.collect { |key| "#{key}_#{language}" }
    derivative_bigrams_fields = language_field_keys.collect { |key| "#{key}_bigrams" }
    hash.except(*(derivative_bigrams_fields + derivative_language_fields))
  end
end