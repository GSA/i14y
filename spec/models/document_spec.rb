# frozen_string_literal: true

require 'rails_helper'

describe Document do
  subject(:document) { described_class.new(valid_params) }

  let(:valid_params) do
    {
      id: 'a123',
      language: 'en',
      path: 'http://www.agency.gov/page1.html',
      title: 'My Title',
      created: DateTime.new(2020, 1, 1),
      changed: DateTime.new(2020, 1, 2),
      description: 'My Description',
      content: 'some content',
      mime_type: 'text/html',
      promote: true,
      tags: 'this,that',
      click_count: 6
    }
  end

  describe 'attributes' do
    it do
      is_expected.to have_attributes(
        id: 'a123',
        language: 'en',
        path: 'http://www.agency.gov/page1.html',
        title: 'My Title',
        created: DateTime.new(2020, 1, 1),
        changed: DateTime.new(2020, 1, 2),
        description: 'My Description',
        content: 'some content',
        promote: true,
        tags: 'this,that',
        click_count: 6
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
