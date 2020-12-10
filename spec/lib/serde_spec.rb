require 'rails_helper'

describe Serde do
  let(:language_field_keys) { Document::LANGUAGE_FIELDS }

  describe '.serialize_hash' do
    subject(:serialize_hash) do
      Serde.serialize_hash(original_hash, :en, language_field_keys)
    end
    let(:original_hash) do
      ActiveSupport::HashWithIndifferentAccess.new(
        { "title" => "my title",
          "description" => "my description",
          "content" => "my content",
          "path" => "http://www.foo.gov/bar.html",
          "promote" => false,
          "tags" => "this that",
          "created" => "2018-01-01T12:00:00Z",
          "changed" => "2018-02-01T12:00:00Z" }
      )
    end

    it 'stores the language fields with the language suffix' do
      expect(serialize_hash).to eq(
        { "path" => "http://www.foo.gov/bar.html",
          "promote" => false,
          "tags" => ["this that"],
          "created" => "2018-01-01T12:00:00Z",
          "changed" => "2018-02-01T12:00:00Z",
          "title_en" => "my title",
          "description_en" => "my description",
          "content_en" => "my content",
          "basename" => "bar",
          "extension" => "html",
          "url_path" => "/bar.html",
          "domain_name" => "www.foo.gov"
        }
      )
    end

    context 'when language fields contain HTML/CSS' do
      let(:html) do
        <<~HTML
          <div style="height: 100px; width: 100px;"></div>
          <p>hello & goodbye!</p>
        HTML
      end

      let(:original_hash) do
        ActiveSupport::HashWithIndifferentAccess.new(
          title: '<b><a href="http://foo.com/">foo</a></b><img src="bar.jpg">',
          description: html,
          content: "this <b>is</b> <a href='http://gov.gov/url.html'>html</a>"
        )
      end

      it 'sanitizes the language fields' do
        expect(serialize_hash).to match(hash_including(
          title_en: 'foo',
          description_en: 'hello & goodbye!',
          content_en: 'this is html'
        ))
      end
    end
  end

  describe '.deserialize_hash' do
    subject(:deserialize_hash) do
      Serde.deserialize_hash(original_hash, :en, language_field_keys)
    end
    let(:original_hash) do
      ActiveSupport::HashWithIndifferentAccess.new(
        { "created_at" => "2018-08-09T21:36:50.087Z",
          "updated_at" => "2018-08-09T21:36:50.087Z",
          "path" => "http://www.foo.gov/bar.html",
          "language" => "en",
          "created" => "2018-08-09T19:36:50.087Z",
          "updated" => "2018-08-09T14:36:50.087-07:00",
          "changed" => "2018-08-09T14:36:50.087-07:00",
          "promote" => true,
          "tags" => "this that",
          "title_en" => "my title",
          "description_en" => "my description",
          "content_en" => "my content",
          "basename" => "bar",
          "extension" => "html",
          "url_path" => "/bar.html",
          "domain_name" => "www.foo.gov"
        }
      )
    end
    let(:language_field_keys) { %i[title description content] }

    it 'removes the language suffix from the text fields' do
      expect(deserialize_hash).to eq(
        { "created_at" => "2018-08-09T21:36:50.087Z",
          "updated_at" => "2018-08-09T21:36:50.087Z",
          "path" => "http://www.foo.gov/bar.html",
          "language" => "en",
          "created" => "2018-08-09T19:36:50.087Z",
          "title" => "my title",
          "description" => "my description",
          "content" => "my content",
          "updated" => "2018-08-09T14:36:50.087-07:00",
          "changed" => "2018-08-09T14:36:50.087-07:00",
          "promote" => true,
          "tags" => "this that"
        }
      )
    end
  end

  context '.uri_params_hash' do
    subject(:result) { Serde.uri_params_hash(path) }
    let(:path) { 'https://www.agency.gov/directory/page1.html' }

    it 'computes basename' do
      expect(result[:basename]).to eq('page1')
    end

    it 'computes filename extension' do
      expect(result[:extension]).to eq('html')
    end

    context 'when the extension has uppercase characters' do
      let(:path) { 'https://www.agency.gov/directory/PAGE1.PDF' }

      it 'computes a downcased version of filename extension' do
        expect(result[:extension]).to eq('pdf')
      end
    end

    context 'when there is no filename extension' do
      let(:path) { 'https://www.agency.gov/directory/page1' }

      it 'computes an empty filename extension' do
        expect(result[:extension]).to eq('')
      end
    end

    it 'computes url_path' do
      expect(result[:url_path]).to eq('/directory/page1.html')
    end

    it 'computes domain_name' do
      expect(result[:domain_name]).to eq('www.agency.gov')
    end
  end
end
