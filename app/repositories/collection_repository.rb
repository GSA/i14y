# frozen_string_literal: true

class CollectionRepository
  include Repository

  klass Collection
  client ES.client
  index_name index_namespace
  settings number_of_shards: 1, number_of_replicas: 1

  def deserialize(hash)
    klass.new(source_hash(hash))
  end
end
