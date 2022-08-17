# frozen_string_literal: true

require 'rails_helper'

describe Document do
  subject(:document) { described_class.new(valid_params) }

  let(:valid_params) do
    {
      id: 'b246',
      language: 'en',
      path: 'http://www.document_agency.gov/page1.html',
      title: 'Title of Document',
      created: DateTime.new(2022, 2, 2),
      changed: DateTime.new(2022, 2, 4),
      description: 'Description of Document',
      content: 'content document content',
      mime_type: 'text/plain',
      promote: true,
      tags: 'argle_tag,bargle_tag',
      click_count: 6
    }
  end

  describe 'attributes' do
    it do
      is_expected.to have_attributes(
        click_count: 6,
        tags: 'argle_tag,bargle_tag',
        promote: true,
        mime_type: 'text/plain',
        content: 'content document content',
        description: 'Description of Document',
        changed: DateTime.new(2022, 2, 4),
        created: DateTime.new(2022, 2, 2),
        title: 'Title of Document',
        path: 'http://www.document_agency.gov/page1.html',
        language: 'en',
        id: 'b246'
      )
    end

    it 'sets default timestamps' do
      expect(document.created_at).to be_a Time
      expect(document.updated_at).to be_a Time
    end

    context 'with the minimum required params' do
      subject(:document) do
        described_class.new(
          language: 'en',
          path: 'https://foo.gov'
        )

        it { is_expected.to be_valid }
      end
    end
  end

  describe 'invalid?' do
    subject(:document) { described_class.new(valid_params.merge(mime_type: 'text/not_a_valid_mime_type')) }

    it 'returns true and sets an error message for invalid MIME type' do
      expect(document.invalid?).to be true
      expect(document.errors.messages[:mime_type]).to include 'is invalid'
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_presence_of(:language) }
    it { is_expected.to be_valid }
  end
end
