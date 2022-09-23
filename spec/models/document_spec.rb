# frozen_string_literal: true

require 'rails_helper'

describe Document do
  subject(:document) { described_class.new(valid_params) }

  let(:valid_params) do
    {
      id: 'a123',
      title: 'My Title',
      path: 'http://www.agency.gov/page1.html',
      audience: 'Everyone',
      changed: DateTime.new(2020, 1, 2),
      click_count: 5,
      content: 'some content',
      content_type: 'article',
      created: DateTime.new(2020, 1, 1),
      description: 'My Description',
      language: 'en',
      mime_type: 'text/html',
      promote: true,
      searchgov_custom1: 'custom content with spaces',
      searchgov_custom2: 'comma, separated, custom, content',
      searchgov_custom3: '',
      tags: 'this,that'
    }
  end

  describe 'attributes' do
    it do
      is_expected.to have_attributes(
        id: 'a123',
        title: 'My Title',
        path: 'http://www.agency.gov/page1.html',
        audience: 'Everyone',
        changed: DateTime.new(2020, 1, 2),
        click_count: 5,
        content: 'some content',
        content_type: 'article',
        created: DateTime.new(2020, 1, 1),
        description: 'My Description',
        language: 'en',
        mime_type: 'text/html',
        promote: true,
        searchgov_custom1: 'custom content with spaces',
        searchgov_custom2: 'comma, separated, custom, content',
        searchgov_custom3: '',
        tags: 'this,that'
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
      end

      it { is_expected.to be_valid }
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_presence_of(:language) }
    it { is_expected.to be_valid }

    context 'when the MIME type is invalid' do
      subject(:document) do
        described_class.new(valid_params.merge(mime_type: 'text/not_a_valid_mime_type'))
      end

      it { is_expected.to be_invalid }

      it 'generates an error message' do
        document.valid?
        expect(document.errors.messages[:mime_type]).to include 'is invalid'
      end
    end
  end
end