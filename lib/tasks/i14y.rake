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

  desc "Copies data from one version of the i14y index to the next (e.g., collections, documents) and updates the alias"
  task :reindex, [:entity_name] => [:environment] do |t, args|
    entity_name = args.entity_name
    persistence_model_klass = entity_name.singularize.camelize.constantize
    klass = entity_name.camelize.constantize
    template_generator = klass.new
    Elasticsearch::Persistence.client.indices.put_template(name: entity_name,
                                                           body: template_generator.body,
                                                           order: 0)

    wildcard = [persistence_model_klass.index_namespace, '*'].join
    aliases = Elasticsearch::Persistence.client.indices.get_alias(name: wildcard)
    aliases.each do |old_es_index_name, alias_names|
      alias_name = alias_names['aliases'].keys.first
      persistence_model_klass.index_name = old_es_index_name
      new_es_index_name = next_version(old_es_index_name)
      puts "Beginning copy of #{persistence_model_klass.count} #{entity_name} from #{old_es_index_name} to #{new_es_index_name}"
      persistence_model_klass.create_index!(index: new_es_index_name)
      persistence_model_klass.index_name = new_es_index_name
      since_timestamp = Time.now
      host_hash = Elasticsearch::Persistence.client.transport.hosts.first
      base_url = "#{host_hash[:protocol]}://#{host_hash[:host]}:#{host_hash[:port]}/"
      old_es_index_url = base_url + old_es_index_name
      new_es_index_url = base_url + new_es_index_name
      stream2es(old_es_index_url, new_es_index_url)
      move_alias(alias_name, old_es_index_name, new_es_index_name)
      stream2es(old_es_index_url, new_es_index_url, since_timestamp)
      puts "New #{new_es_index_name} index now contains #{persistence_model_klass.count} #{entity_name}"
      Elasticsearch::Persistence.client.indices.delete(index: old_es_index_name)
    end
  end

  desc "Deletes templates, indexes, and reader/writer aliases for all i14y models. Useful for development."
  task clear_all: :environment do
    Dir[Rails.root.join('app', 'templates', '*.rb')].each do |template_generator|
      entity_name = File.basename(template_generator, '.rb')
      Elasticsearch::Persistence.client.indices.delete_template(name: entity_name) rescue Elasticsearch::Transport::Transport::Errors::NotFound
    end
    Elasticsearch::Persistence.client.indices.delete(index: [Rails.env, APP_NAME, '*'].join('-'))
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
