class Document
  include Elasticsearch::Persistence::Model
  index_name [Rails.env, Rails.application.engine_name.split('_').first, self.name.tableize].join('-')

  attribute :document_id, String
  validates :document_id, presence: true
  attribute :path, String
  validates :path, presence: true
  attribute :language, String
  validates :language, presence: true
  attribute :updated, DateTime
  attribute :created, DateTime
  validates :created, presence: true
  attribute :promote, Boolean

  after_save { Rails.logger.info "Successfully saved #{self.class.name.tableize}: #{self}" }

end