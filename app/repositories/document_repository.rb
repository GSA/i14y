# frozen_string_literal: true

class DocumentRepository
  include Elasticsearch::Persistence::Repository
  include Elasticsearch::Persistence::Repository::DSL

  extend NamespacedIndex

  klass Document
  client ES.client
  settings number_of_shards: 1, number_of_replicas: 1

  def serialize(document)
    document_hash = ActiveSupport::HashWithIndifferentAccess.new(super)
    Serde.serialize_hash(document_hash, document_hash[:language])
  end

  def deserialize(hash)
    doc_hash = hash['_source']
    deserialized_hash = Serde.deserialize_hash(doc_hash,
                                               doc_hash['language'])

    document = Document.new deserialized_hash
    document.instance_variable_set :@_id, hash['_id']
    document.instance_variable_set :@_index, hash['_index']
    document.instance_variable_set :@_type, hash['_type']
    document.instance_variable_set :@_version, hash['_version']

    document.instance_variable_set :@hit, Hashie::Mash.new(
      hash.except('_index', '_type', '_id', '_version', '_source')
    )

    document.instance_variable_set(:@persisted, true)
    document
  end
end
