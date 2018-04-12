require 'csv'

Migration = Struct.new(:collection_name, :primary_shards, :replica_shards, :reindex_with_task, :ingest_pipeline) do
  def create_index
    puts "creating index '#{next_version_index_name}' with primary shard count #{primary_shards}"
    Collection.create_index!({
      index: next_version_index_name,
      settings: {
        number_of_shards: primary_shards,
        number_of_replicas: 0,
      },
    })
  end

  def create_replicas
    puts "setting replica shard count for '#{next_version_index_name}' to #{replica_shards}"
    Elasticsearch::Persistence.client.indices.put_settings({
      index: next_version_index_name,
      body: { index: { number_of_replicas: replica_shards } },
    })
  end

  def delete_previous_index
    puts "deleting index '#{previous_version_index_name}'"
    Elasticsearch::Persistence.client.indices.delete(index: previous_version_index_name)
  end

  def reindex
    dest_pipeline = ingest_pipeline.blank? ? { } : { pipeline: ingest_pipeline }
    wait_for_completion = reindex_with_task == 'n'
    puts "reindexing #{current_version_index_name} into #{next_version_index_name}"
    response = Elasticsearch::Persistence.client.reindex({
      body: {
        source: { index: current_version_index_name },
        dest: { index: next_version_index_name }.merge(dest_pipeline),
      },
      wait_for_completion: wait_for_completion,
    })
    puts "  result: #{response}"
  end

  def update_alias
    puts "updating alias '#{alias_name}' to point to '#{next_version_index_name}' instead of '#{current_version_index_name}'"
    Elasticsearch::Persistence.client.indices.update_aliases({
      body: {
        actions: [
          { add: { index: next_version_index_name, alias: alias_name } },
          { remove: { index: current_version_index_name, alias: alias_name } },
        ],
      }
    })
  end

  def validate!
    raise "reindex_with_task field for '#{collection_name}' must be 'y' or 'n', not '#{reindex_with_task}'" unless %w[y n].include?(reindex_with_task)
  end

  private

  def alias_name
    [Rails.env, I14y::APP_NAME, 'documents', collection_name].join('-')
  end

  def current_version_index_name
    # TODO: bail if there isn't exactly one key
    Elasticsearch::Persistence.client.indices.get_alias(name: alias_name).keys.first
  end

  def next_version_index_name
    current_version_index_name.sub(%r{-v(\d+)$}) { |m| "-v#{$1.to_i.next}" }
  end

  def previous_version_index_name
    current_version_index_name.sub(%r{-v(\d+)$}) { |m| "-v#{$1.to_i.pred}" }
  end
end

namespace :i14y do
  namespace :migrate do
    task :read_migrations do
      @migrations = if filename = ENV['CSV']
        CSV.read(filename).map { |row| Migration.new(*row) }
      else
        puts 'specify migrations input file with CSV=my_migrations.csv'
        []
      end
      @migrations.each { |m| m.validate! }
    end

    desc 'update the documents template'
    task :update_template => [:environment] do
      puts 'updating documents template'
      Elasticsearch::Persistence.client.indices.put_template({
        body: Documents.new.body,
        name: 'documents',
        order: 0,
      })
    end

    desc 'create each index'
    task :create_indices => [:environment, :read_migrations] do
      @migrations.each { |m| m.create_index }
    end

    desc 'reindex each index'
    task :reindex_indices => [:environment, :read_migrations] do
      @migrations.each { |m| m.reindex }
    end

    desc 'create replicas for each index'
    task :create_replicas => [:environment, :read_migrations] do
      @migrations.each { |m| m.create_replicas }
    end

    desc 'update aliases to point to new indices instead of old indices'
    task :update_aliases => [:environment, :read_migrations] do
      @migrations.each { |m| m.update_alias }
    end

    desc 'delete all the old indices'
    task :cleanup => [:environment, :read_migrations] do
      @migrations.each { |m| m.delete_previous_index }
    end
  end
end
