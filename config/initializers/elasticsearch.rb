# frozen_string_literal: true

module ES
  ES_CONFIG = Rails.application.config_for(:elasticsearch).freeze

  def self.client
    Elasticsearch::Client.new(ES_CONFIG.merge({randomize_hosts: true, retry_on_failure: true, reload_connections: false, reload_on_failure: false, reload_on_failure: false, transport_options: { ssl: { verify: ENV.fetch("SSL_VERIFY") }}}))
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
