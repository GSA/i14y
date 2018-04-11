namespace :i14y do
  desc "Creates templates, indexes, and reader/writer aliases for all i14y models"
  task setup: :environment do
    Dir[Rails.root.join('app', 'templates', '*.rb')].each do |template_generator|
      entity_name = File.basename(template_generator, '.rb')
      klass = entity_name.camelize.constantize
      template_generator = klass.new
      Elasticsearch::Persistence.client.indices.put_template(name: entity_name,
                                                             body: template_generator.body,
                                                             order: 0,
                                                             create: true)
    end
    es_collections_index_name = [Collection.index_namespace, 'v1'].join('-')
    Collection.create_index!(index: es_collections_index_name)
    Elasticsearch::Persistence.client.indices.put_alias index: es_collections_index_name, name: Collection.index_name
  end

  desc "Deletes templates, indexes, and reader/writer aliases for all i14y models. Useful for development."
  task clear_all: :environment do
    Dir[Rails.root.join('app', 'templates', '*.rb')].each do |template_generator|
      entity_name = File.basename(template_generator, '.rb')
      Elasticsearch::Persistence.client.indices.delete_template(name: entity_name) rescue Elasticsearch::Transport::Transport::Errors::NotFound
    end
    Elasticsearch::Persistence.client.indices.delete(index: [Rails.env, I14y::APP_NAME, '*'].join('-'))
  end

  def next_version(index_name)
    matches = index_name.match(/(.*-v)(\d+)/)
    "#{matches[1]}#{matches[2].succ}"
  end

  def stream2es(old_es_index_url, new_es_index_url, timestamp = nil)
    options = ["--source #{old_es_index_url}", "--target #{new_es_index_url}"]
    if timestamp.present?
      hash = { query: { filtered: { filter: { range: { updated_at: { gte: timestamp } } } } } }
      options << "--query '#{hash.to_json}'"
    end
    result = `#{Rails.root.join('vendor', 'stream2es')} es #{options.join(' ')}`
    puts "Stream2es completed", result
  end

  def move_alias(alias_name, old_index_name, new_index_name)
    update_aliases_hash = { body:
                              { actions: [
                                { remove: { index: old_index_name, alias: alias_name } },
                                { add: { index: new_index_name, alias: alias_name } }
                              ] } }
    Elasticsearch::Persistence.client.indices.update_aliases(update_aliases_hash)
  end

end
