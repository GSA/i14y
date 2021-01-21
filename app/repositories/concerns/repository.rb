# frozen_string_literal: true

require 'active_support/concern'

module Repository
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Persistence::Repository
    include Elasticsearch::Persistence::Repository::DSL

    extend NamespacedIndex

    client ES.client
    settings number_of_shards: 1, number_of_replicas: 1
  end

  def source_hash(hash)
    hash['_source'].merge(id: hash['_id'])
  end
end
