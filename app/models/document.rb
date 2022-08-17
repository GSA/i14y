# frozen_string_literal: true

require 'mini_mime'

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

  validate :mime_type_is_valid

  private

  def mime_type_is_valid
    return unless mime_type

    errors.add(:mime_type, 'is invalid') unless MiniMime.lookup_by_content_type(mime_type)
  end
end
