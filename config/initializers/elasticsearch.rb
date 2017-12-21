yaml = YAML.load_file("#{Rails.root}/config/elasticsearch.yml")

Elasticsearch::Persistence.client = Elasticsearch::Client.new(log: Rails.env.development?,
                                                              hosts: yaml['hosts'],
                                                              user: yaml['user'],
                                                              password: yaml['password'],
                                                              randomize_hosts: true,
                                                              retry_on_failure: true,
                                                              reload_connections: true)

if Rails.env.development?
  logger = ActiveSupport::Logger.new(STDERR)
  logger.level = Logger::DEBUG
  logger.formatter = proc { |s, d, p, m| "\e[2m#{m}\n\e[0m" }
  Elasticsearch::Persistence.client.transport.logger = logger
end
