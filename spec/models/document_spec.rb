# frozen_string_literal: true

require 'rails_helper'

describe Document do
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
      click_count: 5
    }
  end

  describe 'attributes' do
    subject(:document) { described_class.new(valid_params) }

    it do
      is_expected.to have_attributes(valid_params)
    end

    it 'is valid for valid MIME type' do
      expect(document.valid?).to be true
    end

    it 'sets default timestamps' do
      expect(document.created_at).to be_a Time
      expect(document.updated_at).to be_a Time
    end
  end

  describe 'invalid?' do
    subject(:document) { described_class.new(valid_params.merge(mime_type: 'text/not_a_valid_mime_type')) }

    it 'returns true for invalid MIME type' do
      expect(document.invalid?).to be true
    end
  end

  describe 'valid?' do
    subject(:document) { described_class.new(missing_mime_type_params) }

    let(:missing_mime_type_params) do
      valid_params.delete(:mime_type)
      valid_params
    end

    it 'returns true for missing MIME type' do
      expect(document.mime_type).to be nil
      expect(document.valid?).to be true
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_presence_of(:language) }
  end
end
