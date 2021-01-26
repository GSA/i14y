# frozen_string_literal: true

class Collection
  include ActiveModel::Serializers::JSON
  include ActiveModel::Validations
  include Virtus.model

  attribute :id, String
  attribute :token, String
  attribute :created_at, Time, default: proc { Time.now.utc }
  attribute :updated_at, Time, default: proc { Time.now.utc }

  validates :token, presence: true

  def document_total
    document_repository.count
  end

  def last_document_sent
    document_repository.search("*:*", {size:1, sort: "updated_at:desc"}).
      results.first.updated_at.utc.to_s
  rescue
    nil
  end

  private

  def document_repository
    @document_repository = DocumentRepository.new(
      index_name: DocumentRepository.index_namespace(id)
    )
  end
end
