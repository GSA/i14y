# frozen_string_literal: true

config = Rails.application.config_for(:elasticsearch).freeze

Elasticsearch::Persistence.client = Elasticsearch::Client.new(log: Rails.env.development?,
                                                              hosts: config['hosts'],
                                                              user: config['user'],
                                                              password: config['password'],
                                                              randomize_hosts: true,
                                                              retry_on_failure: true,
                                                              reload_connections: true)

if Rails.env.development?
  logger = ActiveSupport::Logger.new(STDERR)
  logger.level = Logger::DEBUG
  logger.formatter = proc { |_s, _d, _p, m| "\e[2m#{m}\n\e[0m" }
  Elasticsearch::Persistence.client.transport.logger = logger
end
