# frozen_string_literal: true

require 'rails_helper'
require 'uri'

describe API::V1::Documents do
  let(:id) { 'some really!weird@id.name' }
  let(:credentials) do
    ActionController::HttpAuthentication::Basic.encode_credentials('test_index',
                                                                   'test_key')
  end
  let(:valid_session) do
    { HTTP_AUTHORIZATION: credentials }
  end
  let(:allow_updates) { true }
  let(:maintenance_message) { nil }
  let(:documents_index_name) { DocumentRepository.index_namespace('test_index') }
  let(:document_repository) { DocumentRepository.new(index_name: documents_index_name) }

  before(:all) do
    yaml = YAML.load_file("#{Rails.root}/config/secrets.yml")
    env_secrets = yaml[Rails.env]
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials env_secrets['admin_user'], env_secrets['admin_password']
    valid_collection_session = { HTTP_AUTHORIZATION: credentials }
    valid_collection_params = { handle: 'test_index', token: 'test_key' }
    post '/api/v1/collections', params: valid_collection_params, headers: valid_collection_session
  end

  before do
    I14y::Application.config.updates_allowed = allow_updates
    I14y::Application.config.maintenance_message = maintenance_message
  end

  after do
    I14y::Application.config.updates_allowed = true
    clear_index(documents_index_name)
  end

  describe 'POST /api/v1/documents' do
    subject(:post_document) do
      post '/api/v1/documents', params: document_params, headers: valid_session
      document_repository.refresh_index!
    end

    let(:valid_params) do
      { document_id: id,
        title:       'my title',
        path:        'http://www.gov.gov/goo.html',
        description: 'my desc',
        promote:     true,
        language:    'hy',
        content:     'my content',
        tags:        'Foo, Bar blat' }
    end
    let(:document_params) { valid_params }

    context 'success case' do
      before do
        post_document
      end

      it 'returns success message as JSON' do
        expect(response.status).to eq(201)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 200,
                                     'developer_message' => 'OK',
                                     'user_message' => 'Your document was successfully created.'))
      end

      it 'uses the collection handle and the document_id in the Elasticsearch ID' do
        expect(document_repository.find(id)).to be_present
      end

      it 'stores the appropriate fields in the Elasticsearch document' do
        document = document_repository.find(id)
        expect(document.path).to eq('http://www.gov.gov/goo.html')
        expect(document.promote).to be_truthy
        expect(document.title).to eq('my title')
        expect(document.description).to eq('my desc')
        expect(document.content).to eq('my content')
        expect(document.tags).to match_array(['bar blat', 'foo'])
        expect(document.created_at).to be_an_instance_of(Time)
        expect(document.updated_at).to be_an_instance_of(Time)
      end

      context 'when a "created" value is provided but not "changed"' do
        let(:valid_params) do
          { document_id: id,
            title:       'my title',
            path:        'http://www.gov.gov/goo.html',
            description: 'my desc',
            language:    'hy',
            content:     'my content',
            created:     '2020-01-01T10:00:00Z' }
        end

        it 'sets "changed" to be the same as "created"' do
          document = document_repository.find(id)
          expect(document.changed).to eq '2020-01-01T10:00:00Z'
        end
      end

      it_behaves_like 'a data modifying request made during read-only mode'
    end

    context 'trying to create an existing document' do
      let(:document_params) { valid_params.merge(document_id: 'its_a_dupe') }

      before do
        create_document(valid_params.merge(id: 'its_a_dupe'), document_repository)
        post_document
      end

      it 'returns failure message as JSON' do
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 422,
                                     'developer_message' => 'Document already exists with that ID'))
      end
    end

    context 'invalid language param' do
      let(:document_params) { valid_params.merge(language: 'qq') }

      before { post_document }

      it 'returns failure message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 400,
                                     'developer_message' => 'language does not have a valid value'))
      end
    end

    context 'slash in id' do
      let(:document_params) { valid_params.merge(document_id: 'a1/234') }

      before { post_document }

      it 'returns failure message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 400,
                                     'developer_message' => "document_id cannot contain any of the following characters: ['/']"))
      end
    end

    context 'id larger than 512 bytes' do
      let(:string_with_513_bytes_but_only_257_characters) do
        two_byte_character = '\u00b5'
        'x' + two_byte_character * 256
      end

      let(:document_params) do
        valid_params.merge(document_id: string_with_513_bytes_but_only_257_characters)
      end

      before { post_document }

      it 'returns failure message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 400,
                                     'developer_message' => 'document_id cannot be more than 512 bytes long'))
      end
    end

    context 'missing language param' do
      let(:document_params) { valid_params.except(:language) }

      before { post_document }

      it 'uses English (en) as default' do
        expect(document_repository.find(id).language).to eq('en')
      end
    end

    context 'a required parameter is empty/blank' do
      let(:document_params) { valid_params.merge(title: ' ') }

      before { post_document }

      it 'returns failure message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 400,
                                     'developer_message' => 'title is empty'))
      end
    end

    context 'path URL is poorly formatted' do
      let(:document_params) { valid_params.merge(path: 'http://www.gov.gov/ goo.html') }

      before { post_document }

      it 'returns failure message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 400,
                                     'developer_message' => 'path is invalid'))
      end
    end

    context 'failed authentication/authorization' do
      let(:credentials) do
        ActionController::HttpAuthentication::Basic.encode_credentials('test_index',
                                                                       'bad_key')
      end

      before { post_document }

      it 'returns error message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 400,
                                     'developer_message' => 'Unauthorized'))
      end
    end

    context 'something terrible happens during authentication' do
      before do
        allow(ES).to receive(:collection_repository).
          and_raise(Elasticsearch::Transport::Transport::Errors::BadRequest)
        post_document
      end

      it 'returns error message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 400,
                                     'developer_message' => 'Unauthorized'))
      end
    end

    context 'something terrible happens creating the document' do
      before do
        allow(Document).to receive(:new) { raise_error(Exception) }
        post_document
      end

      it 'returns failure message as JSON' do
        expect(response.status).to eq(500)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 500,
                                     'developer_message' => "Something unexpected happened and we've been alerted."))
      end
    end

  end

  describe 'PUT /api/v1/documents/{document_id}' do
    subject(:put_document) do
      put "/api/v1/documents/#{URI.encode(id)}",
        params: update_params,
        headers: valid_session
      document_repository.refresh_index!
    end

    let(:update_params) do
      {
        title:       'new title',
        description: 'new desc',
        content:     'new content',
        path:        'http://www.next.gov/updated.html',
        promote:     false,
        tags:        'new category',
        changed:     '2016-01-01T10:00:01Z',
        click_count: 1000
      }
    end

    context 'success case' do
      before do
        create_document({id:           id,
                         language:    'en',
                         title:       'hi there 4',
                         description: 'bigger desc 4',
                         content:     'huge content 4',
                         created:     2.hours.ago,
                         updated:     Time.now,
                         promote:     true,
                         path:        'http://www.gov.gov/url4.html'}, document_repository)

        put_document
      end

      it 'returns success message as JSON' do
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 200,
                                     'developer_message' => 'OK',
                                     'user_message' => 'Your document was successfully updated.'))
      end

      it 'updates the document' do
        document = document_repository.find(id)
        expect(document.path).to eq('http://www.next.gov/updated.html')
        expect(document.promote).to be_falsey
        expect(document.title).to eq('new title')
        expect(document.description).to eq('new desc')
        expect(document.content).to eq('new content')
        expect(document.tags).to match_array(['new category'])
        expect(document.changed).to eq('2016-01-01T10:00:01Z')
        expect(document.click_count).to eq(1000)
      end

      it_behaves_like 'a data modifying request made during read-only mode'
    end

    context 'when time has passed since the document was created' do
      before do
        create_document({
          id:           id,
          language:    'en',
          title:       'hi there 4',
          description: 'bigger desc 4',
          content:     'huge content 4',
          path:        'http://www.gov.gov/url4.html'
        }, document_repository)
        # Force-update the timestamps to avoid fooling the specs with any
        # automagic trickery
        ES.client.update(
          index: documents_index_name,
          id: id,
          body: {
            doc: {
              updated_at: 1.year.ago,
              created_at: 1.year.ago
            }
          },
          type: '_doc'
        )
        document_repository.refresh_index!
      end

      it 'updates the updated_at timestamp' do
        expect { put_document }.to change { document_repository.find(id).updated_at }
      end

      it 'does not update the created_at timestamp' do
        expect { put_document }.not_to change { document_repository.find(id).created_at }
      end
    end
  end

  describe 'DELETE /api/v1/documents/{document_id}' do
    subject(:delete_document) do
      delete "/api/v1/documents/#{URI.encode(id)}", headers: valid_session
    end

    context 'success case' do
      before do
        create_document({
          id:          id,
          language:    'en',
          title:       'hi there 4',
          description: 'bigger desc 4',
          content:     'huge content 4',
          created:     2.hours.ago,
          updated:     Time.now,
          promote:     true,
          path:        'http://www.gov.gov/url4.html'
        }, document_repository)

        delete_document
      end

      it 'returns success message as JSON' do
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 200,
                                     'developer_message' => 'OK',
                                     'user_message' => 'Your document was successfully deleted.'))
      end

      it 'deletes the document' do
        expect(document_repository.exists?(id)).to be_falsey
      end

      it_behaves_like 'a data modifying request made during read-only mode'
    end

    context 'deleting a non-existent document' do
      let(:id) { 'nonexistent' }

      before { delete_document }

      it 'returns error message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).
          to match(hash_including('status' => 400,
                                     'developer_message' => 'Resource could not be found.'))
      end
    end
  end
end
