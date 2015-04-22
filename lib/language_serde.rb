class LanguageSerde
  def self.serialize_hash(hash, language, language_field_keys)
    result_hash = hash.except(*language_field_keys)
    language_field_keys.each do |key|
      value = hash[key.to_sym]
      result_hash.store("#{key}_#{language}", value) if value.present?
    end
    result_hash
  end

  def self.deserialize_hash(hash, language, language_field_keys)
    result_hash = hash.except(*language_field_keys)
    language_field_keys.each do |key|
      value = hash["#{key}_#{language}"]
      result_hash.store(key, value) if value.present?
    end
    result_hash
  end
end