class Document
  include Elasticsearch::Persistence::Model
  extend NamespacedIndex

  settings index: { number_of_shards: 1 }

  index_name index_namespace

  attribute :path, String, mapping: { type: 'keyword' }
  validates :path, presence: true
  attribute :language, String, mapping: { type: 'keyword' }
  validates :language, presence: true
  attribute :created, DateTime

  attribute :title, String
  attribute :description, String
  attribute :content, String

  attribute :updated, DateTime
  attribute :changed, DateTime
  attribute :promote, Boolean
  attribute :tags, String, mapping: { type: 'keyword' }
  attribute :click_count, Integer

  LANGUAGE_FIELDS = [:title, :description, :content]

  gateway do
    def serialize(document)
      Serde.serialize_hash(document.to_hash, document.language, LANGUAGE_FIELDS)
    end

    def deserialize(hash)
      doc_hash = hash['_source']
      deserialized_hash = Serde.deserialize_hash(doc_hash, doc_hash['language'], LANGUAGE_FIELDS)

      document = Document.new deserialized_hash
      document.instance_variable_set :@_id, hash['_id']
      document.instance_variable_set :@_index, hash['_index']
      document.instance_variable_set :@_type, hash['_type']
      document.instance_variable_set :@_version, hash['_version']

      document.instance_variable_set :@hit, Hashie::Mash.new(hash.except('_index', '_type', '_id', '_version', '_source'))

      document.instance_variable_set(:@persisted, true)
      document
    end
  end

end
