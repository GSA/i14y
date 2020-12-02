# frozen_string_literal: true

module ES
  CONFIG = YAML.load_file("#{Rails.root}/config/elasticsearch.yml").presence.freeze

  def self.client
    Elasticsearch::Client.new(log: Rails.env.development?,
                              hosts: CONFIG['hosts'],
                              user: CONFIG['user'],
                              password: CONFIG['password'],
                              randomize_hosts: true,
                              retry_on_failure: true,
                              reload_connections: true)
  end

  def self.collection_repository
    CollectionRepository.new
  end
end

if Rails.env.development?
  logger = ActiveSupport::Logger.new(STDERR)
  logger.level = Logger::DEBUG
  logger.formatter = proc { |_s, _d, _p, m| "\e[2m#{m}\n\e[0m" }
  ES.client.transport.logger = logger
end
