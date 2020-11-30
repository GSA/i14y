# frozen_string_literal: true

class CollectionRepository
  include Elasticsearch::Persistence::Repository

  klass Collection
  client ES.client
end
