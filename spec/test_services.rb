module TestServices
  module_function

  def create_es_indexes
    es_collections_index_name = [Rails.env, I14y::APP_NAME, 'collections', 'v1'].join('-')
    Collection.create_index!(index: es_collections_index_name)
    Elasticsearch::Persistence.client.indices.put_alias index: es_collections_index_name, name: Collection.index_name
  end

  def delete_es_indexes
    Elasticsearch::Persistence.client.indices.delete(index: [Rails.env, I14y::APP_NAME, '*'].join('-'))
  end
end
