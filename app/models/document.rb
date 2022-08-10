# frozen_string_literal: true

class Document
  include Virtus.model
  include ActiveModel::Validations

  attribute :id, String
  attribute :path, String, mapping: { type: 'keyword' }
  attribute :language, String, mapping: { type: 'keyword' }
  attribute :created, DateTime
  attribute :title, String
  attribute :description, String
  attribute :content, String
  attribute :mime_type, String
  attribute :updated, DateTime
  attribute :changed, DateTime, default: ->(doc, _attr) { doc.created }
  attribute :promote, Boolean
  attribute :tags, String, mapping: { type: 'keyword' }
  attribute :click_count, Integer
  attribute :created_at, Time, default: proc { Time.now.utc }
  attribute :updated_at, Time, default: proc { Time.now.utc }

  validates :language, presence: true
  validates :path, presence: true

  validates_each :mime_type do |record, attr, value|
    record.errors.add(attr, 'is not a recognized MIME type.') unless value.blank? || MIME::Types.include?(value)
  end
end
