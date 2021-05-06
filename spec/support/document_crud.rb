# frozen_string_literal: true

module DocumentCrud
  def create_document(params, repository)
    document = Document.new(params)
    # Ensure this helper method is only used to create valid docs
    document.validate!
    repository.save(document)
    # Ensure the document is searchable
    repository.refresh_index!
  end
end
