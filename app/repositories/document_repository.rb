# frozen_string_literal: true

class DocumentRepository
  include Elasticsearch::Persistence::Repository

  klass Document
  client ES.client
end
