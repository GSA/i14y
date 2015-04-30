class Collection
  include Elasticsearch::Persistence::Model
  extend NamespacedIndex

  index_name index_namespace
  attribute :token, String
  validates :token, presence: true
end