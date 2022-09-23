# frozen_string_literal: true

require 'mini_mime'

class Document
  include Virtus.model
  include ActiveModel::Validations

  attribute :audience, String
  attribute :changed, DateTime, default: ->(doc, _attr) { doc.created }
  attribute :click_count, Integer
  attribute :content, String
  attribute :content_type, String
  attribute :created_at, Time, default: proc { Time.now.utc }
  attribute :created, DateTime
  attribute :description, String
  attribute :id, String
  attribute :language, String, mapping: { type: 'keyword' }
  attribute :mime_type, String
  attribute :path, String, mapping: { type: 'keyword' }
  attribute :promote, Boolean
  attribute :searchgov_custom1, String
  attribute :searchgov_custom2, String
  attribute :searchgov_custom3, String
  attribute :tags, String, mapping: { type: 'keyword' }
  attribute :title, String
  attribute :updated_at, Time, default: proc { Time.now.utc }
  attribute :updated, DateTime

  validates :language, presence: true
  validates :path, presence: true

  validate :mime_type_is_valid

  private

  def mime_type_is_valid
    return unless mime_type

    errors.add(:mime_type, 'is invalid') unless MiniMime.lookup_by_content_type(mime_type)
  end
end
