class Collection
  include Elasticsearch::Persistence::Model
  index_name [Rails.env, Rails.application.engine_name.split('_').first, self.name.tableize].join('-')
  attribute :token, String
  validates :token, presence: true

  after_save { Rails.logger.info "Successfully saved #{self.class.name.tableize}: #{self}" }

end