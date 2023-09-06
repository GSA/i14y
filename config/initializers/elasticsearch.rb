# frozen_string_literal: true

module ES
  DEFAULT_CONFIG = Rails.application.config_for(:elasticsearch).freeze

  def self.client
    Elasticsearch::Client.new(DEFAULT_CONFIG.merge(config))
  end

  def self.collection_repository
    CollectionRepository.new
  end

  private

  def config
    {
      randomize_hosts: true,
      retry_on_failure: true,
      reload_connections: true
    }
  end
end

if Rails.env.development?
  logger = ActiveSupport::Logger.new(STDERR)
  logger.level = Logger::DEBUG
  logger.formatter = proc { |_s, _d, _p, m| "\e[2m#{m}\n\e[0m" }
  ES.client.transport.logger = logger
end
