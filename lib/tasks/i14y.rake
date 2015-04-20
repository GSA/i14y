namespace :i14y do
  desc "Creates templates, indexes, and reader/writer aliases for all i14y models"
  task setup_all: :environment do
    Dir[Rails.root.join('config', 'templates', '*.json')].map do |template_file|
      entity_name = File.basename(template_file, '.*')
      Elasticsearch::Persistence.client.indices.put_template(name: entity_name,
                                                             body: File.read(template_file),
                                                             order: 0,
                                                             create: true)
      persistence_model_klass = entity_name.singularize.camelize.constantize
      es_index_name = [index_namespace(entity_name), 'v1'].join('-')
      persistence_model_klass.create_index!(index: es_index_name)
      Elasticsearch::Persistence.client.indices.put_alias index: es_index_name, name: persistence_model_klass.index_name
    end
    Document.create(document_id: "a1234", language: 'en', title_en: "hi there", description_en: 'bigger desc', content_en: "huge content",
                    created: 1.hour.ago, changed: Time.now, updated: Time.now, promote: true, path: "http://www.gov.gov/url.html")
  end

  desc "Copies data from one version of the i14y index to the next (e.g., collections, documents)"
  task :reindex, [:entity_name] => [:environment] do |t, args|
    entity_name = args.entity_name
    persistence_model_klass = entity_name.singularize.camelize.constantize
    template_file = Rails.root.join('config', 'templates', "#{entity_name}.json")
    Elasticsearch::Persistence.client.indices.put_template(name: entity_name,
                                                           body: File.read(template_file),
                                                           order: 0)
    old_es_index_name = Elasticsearch::Persistence.client.indices.get_alias(name: persistence_model_klass.index_name).keys.first
    new_es_index_name = old_es_index_name.succ
    puts "Beginning copy of #{persistence_model_klass.count} #{entity_name} from #{old_es_index_name} to #{new_es_index_name}"
    persistence_model_klass.create_index!(index: new_es_index_name)
    since_timestamp = Time.now
    host_hash = Elasticsearch::Persistence.client.transport.hosts.first
    base_url = "#{host_hash[:protocol]}://#{host_hash[:host]}:#{host_hash[:port]}/"
    old_es_index_url = base_url + old_es_index_name
    new_es_index_url = base_url + new_es_index_name
    stream2es(old_es_index_url, new_es_index_url)
    move_alias(persistence_model_klass.index_name, old_es_index_name, new_es_index_name)
    stream2es(old_es_index_url, new_es_index_url, since_timestamp)
    puts "New #{new_es_index_name} index now contains #{persistence_model_klass.count} #{entity_name}"
    Elasticsearch::Persistence.client.indices.delete(index: old_es_index_name)
  end

  desc "Deletes templates, indexes, and reader/writer aliases for all i14y models. Useful for development."
  task clear_all: :environment do
    Dir[Rails.root.join('config', 'templates', '*.json')].map do |template_file|
      entity_name = File.basename(template_file, '.*')
      Elasticsearch::Persistence.client.indices.delete_template(name: entity_name) rescue Elasticsearch::Transport::Transport::Errors::NotFound
    end
    Elasticsearch::Persistence.client.indices.delete(index: [Rails.env, Rails.application.engine_name.split('_').first, '*'].join('-'))
  end

  def index_namespace(entity_name)
    [Rails.env, Rails.application.engine_name.split('_').first, entity_name].join('-')
  end

  def stream2es(old_es_index_url, new_es_index_url, timestamp = nil)
    options = ["--source #{old_es_index_url}", "--target #{new_es_index_url}"]
    if timestamp.present?
      hash = { query: { filtered: { filter: { range: { updated_at: { gte: timestamp } } } } } }
      options << "--query '#{hash.to_json}'"
    end
    result = `#{Rails.root.join(vendor, 'stream2es')} es #{options.join(' ')}`
    puts "Stream2es completed", result
  end

  def move_alias(alias_name, old_index_name, new_index_name)
    Elasticsearch::Persistence.client.indices.update_aliases(body: {
                                                               actions: [
                                                                 { remove: { index: old_index_name, alias: alias_name } },
                                                                 { add: { index: new_index_name, alias: alias_name } }
                                                               ]
                                                             })
  end

end
