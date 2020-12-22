# frozen_string_literal: true

class CollectionRepository
  include Elasticsearch::Persistence::Repository
  include Elasticsearch::Persistence::Repository::DSL

  extend NamespacedIndex

  klass Collection
  client ES.client
  index_name index_namespace
  settings number_of_shards: 1, number_of_replicas: 1
 end
