class Documents
  def initialize
    @active_synonym_filter_locales = Set.new
    @active_protected_filter_locales = Set.new
  end

  def body
    Jbuilder.encode do |json|
      json.template "*-#{APP_NAME}-documents-*"
      json.settings do
        json.analysis do
          char_filter(json)
          filter(json)
          analyzer(json)
          tokenizer(json)
        end
      end
      json.mappings do
        json.document do
          dynamic_templates(json)
          properties(json)
          json._all { json.enabled false }
        end
      end
    end
  end

  def char_filter(json)
    json.char_filter do
      json.quotes do
        json.type "mapping"
        json.mappings ["\\u0091=>\\u0027", "\\u0092=>\\u0027", "\\u2018=>\\u0027", "\\u2019=>\\u0027", "\\u201B=>\\u0027"]
      end
    end
  end

  def filter(json)
    json.filter do
      json.bigram_filter do
        json.type "shingle"
      end
      language_synonyms(json)
      language_protwords(json)
      language_stemmers(json)
    end
  end

  def analyzer(json)
    json.analyzer do
      GENERIC_ANALYZER_LOCALES.each do |locale|
        json.set! "#{locale}_analyzer" do
          json.type "custom"
          json.filter filter_array(locale)
          json.tokenizer "icu_tokenizer"
          json.char_filter ["html_strip", "quotes"]
        end
      end
      json.fr_analyzer do
        json.type "custom"
        json.filter ["icu_normalizer", "elision", "fr_stem_filter", "icu_folding"]
        json.tokenizer "icu_tokenizer"
        json.char_filter ["html_strip", "quotes"]
      end
      json.ja_analyzer do
        json.type "custom"
        json.filter ["kuromoji_baseform", "ja_pos_filter", "icu_normalizer", "icu_folding", "cjk_width"]
        json.tokenizer "kuromoji_tokenizer"
        json.char_filter ["html_strip"]
      end
      json.ko_analyzer do
        json.type "cjk"
        json.filter []
      end
      json.zh_analyzer do
        json.type "custom"
        json.filter ["smartcn_word", "icu_normalizer", "icu_folding"]
        json.tokenizer "smartcn_sentence"
        json.char_filter ["html_strip"]
      end
      json.default do
        json.type "custom"
        json.filter ["icu_normalizer", "icu_folding"]
        json.tokenizer "icu_tokenizer"
        json.char_filter ["html_strip", "quotes"]
      end
    end
  end

  def tokenizer(json)
    json.tokenizer do
      json.kuromoji do
        json.type "kuromoji_tokenizer"
        json.mode "search"
        json.char_filter ["html_strip"]
      end
    end
  end

  def filter_array(locale)
    array = ["icu_normalizer"]
    array << "#{locale}_protected_filter" if @active_protected_filter_locales.include? locale
    array << "#{locale}_stem_filter"
    array << "#{locale}_synonym" if @active_synonym_filter_locales.include? locale
    array << "icu_folding"
    array
  end

  def properties(json)
    json.properties do
      json.created do
        json.type "date"
      end
      json.updated do
        json.type "date"
      end
      json.document_id do
        json.type "string"
        json.index "not_analyzed"
      end
      json.language do
        json.type "string"
        json.index "not_analyzed"
      end
      json.path do
        json.type "string"
        json.index "not_analyzed"
      end
      json.promote do
        json.type "boolean"
      end
    end
  end

  def dynamic_templates(json)
    json.dynamic_templates do
      language_templates(json)
      json.child! do
        json.string_fields do
          json.mapping do
            json.analyzer "default"
            json.type "string"
          end
          json.match_mapping_type "string"
          json.match "*"
        end
      end
    end
  end

  def language_stemmers(json)
    minimal_stemmers = { de: "german", en: "english", fr: "french", pt: "portuguese" }
    minimal_stemmers.each do |locale, language|
      generic_stemmer(json, locale, language, "minimal")
    end
    light_stemmers = { es: "spanish", fi: "finnish", hu: "hungarian", it: "italian", ru: "russian", sv: "swedish" }
    light_stemmers.each do |locale, language|
      generic_stemmer(json, locale, language, "light")
    end
    json.ja_pos_filter do
      json.type "kuromoji_part_of_speech"
      json.stoptags ["\\u52a9\\u8a5e-\\u683c\\u52a9\\u8a5e-\\u4e00\\u822c", "\\u52a9\\u8a5e-\\u7d42\\u52a9\\u8a5e"]
    end
  end

  def generic_stemmer(json, locale, language, degree)
    json.set! "#{locale}_stem_filter" do
      json.type "stemmer"
      json.name "#{degree}_#{language}"
    end
  end

  def language_templates(json)
    LANGUAGE_ANALYZER_LOCALES.each do |locale|
      json.child! do
        json.set! locale do
          json.match "*_#{locale}"
          json.match_mapping_type "string"
          json.mapping do
            json.analyzer "#{locale}_analyzer"
            json.type "string"
          end
        end
      end
    end
  end

  def language_synonyms(json)
    LANGUAGE_ANALYZER_LOCALES.each do |locale|
      synonym_file = Rails.root.join("config", "locales", "analysis", "#{locale}_synonyms.txt")
      if File.exists? synonym_file
        lines = File.readlines(synonym_file).map(&:chomp).reject { |line| line.starts_with?("#") }
        synonym_filter(json, locale, lines) if lines.any?
      end
    end
  end

  def language_protwords(json)
    LANGUAGE_ANALYZER_LOCALES.each do |locale|
      protwords_file = Rails.root.join("config", "locales", "analysis", "#{locale}_protwords.txt")
      if File.exists? protwords_file
        lines = File.readlines(protwords_file).map(&:chomp).reject { |line| line.starts_with?("#") }
        protected_filter(json, locale, lines)
      end
    end
  end

  def synonym_filter(json, locale, lines)
    @active_synonym_filter_locales.add locale
    json.set! "#{locale}_synonym" do
      json.type "synonym"
      json.synonyms lines
    end
  end

  def protected_filter(json, locale, lines)
    @active_protected_filter_locales.add locale
    json.set! "#{locale}_protected_filter" do
      json.type "keyword_marker"
      json.keywords lines
    end
  end
end