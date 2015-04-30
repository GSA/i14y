require 'rails_helper'

describe API::V1::Documents do
  before(:all) do
    yaml = YAML.load_file("#{Rails.root}/config/secrets.yml")
    env_secrets = yaml[Rails.env]
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials env_secrets['admin_user'], env_secrets['admin_password']
    valid_collection_session = { 'HTTP_AUTHORIZATION' => credentials }
    valid_collection_params = { "handle" => "test_index", "token" => "test_key" }
    post "/api/v1/collections", valid_collection_params, valid_collection_session
    Document.index_name = Document.index_namespace('test_index')
  end

  let(:valid_session) do
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials "test_index", "test_key"
    { 'HTTP_AUTHORIZATION' => credentials }
  end

  describe "POST /api/v1/documents" do
    context 'success case' do
      before do
        Elasticsearch::Persistence.client.delete_by_query index: Document.index_name, q: '*:*'
        valid_params = { "document_id" => "a1234", "title" => "my title", "path" => "http://www.gov.gov/goo.html", "created" => "2013-02-27T10:00:00Z", "description" => "my desc", "promote" => true, "language" => 'hy', "content" => "my content" }
        post "/api/v1/documents", valid_params, valid_session
        Document.refresh_index!
      end

      it 'returns success message as JSON' do
        expect(response.status).to eq(201)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 200, "developer_message" => "OK", "user_message" => "Your document was successfully created."))
      end

      it 'uses the collection handle and the document_id in the Elasticsearch ID' do
        expect(Document.find("a1234")).to be_present
      end

      it 'stores the appropriate fields in the Elasticsearch document' do
        document = Document.find("a1234")
        expect(document.path).to eq("http://www.gov.gov/goo.html")
        expect(document.promote).to be_truthy
        expect(document.title).to eq('my title')
        expect(document.description).to eq('my desc')
        expect(document.content).to eq('my content')
      end
    end

    context 'invalid language param' do
      before do
        valid_params = { "document_id" => "a1234", "title" => "my title", "path" => "http://www.gov.gov/goo.html", "created" => "2013-02-27T10:00:00Z", "description" => "my desc", "promote" => true, "language" => 'qq' }
        post "/api/v1/documents", valid_params, valid_session
      end

      it 'returns failure message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 400, "developer_message" => "language does not have a valid value"))
      end
    end

    context 'missing language param' do
      before do
        valid_params = { "document_id" => "a1234", "title" => "my title", "path" => "http://www.gov.gov/goo.html", "created" => "2013-02-27T10:00:00Z", "description" => "my desc" }
        post "/api/v1/documents", valid_params, valid_session
      end

      it 'uses English (en) as default' do
        expect(Document.find("a1234").language).to eq('en')
      end
    end

    context 'missing at least one of two required parameters' do
      before do
        invalid_params = { "document_id" => "a1234", "title" => "my title", "path" => "http://www.gov.gov/goo.html", "created" => "2013-02-27T10:00:00Z" }
        post "/api/v1/documents", invalid_params, valid_session
      end

      it 'returns failure message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 400, "developer_message" => "content, description are missing, at least one parameter must be provided"))
      end
    end

    context 'a required parameter is empty/blank' do
      before do
        invalid_params = { "document_id" => "a1234", "title" => "   ", "description" => "title is blank", "path" => "http://www.gov.gov/goo.html", "created" => "" }
        post "/api/v1/documents", invalid_params, valid_session
      end

      it 'returns failure message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 400, "developer_message" => "title is empty, created is empty"))
      end
    end

    context 'path URL is poorly formatted' do
      before do
        invalid_params = { "document_id" => "a1234", "title" => "weird URL with blank", "description" => "some description", "path" => "http://www.gov.gov/ goo.html", "created" => "2013-02-27T10:00:00Z" }
        post "/api/v1/documents", invalid_params, valid_session
      end

      it 'returns failure message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 400, "developer_message" => "path is invalid"))
      end
    end

    context 'failed authentication/authorization' do
      before do
        valid_params = { "document_id" => "a1234", "title" => "my title", "path" => "http://www.gov.gov/goo.html", "created" => "2013-02-27T10:00:00Z", "description" => "my desc", "promote" => true }
        bad_credentials = ActionController::HttpAuthentication::Basic.encode_credentials "nope", "wrong"

        valid_session = { 'HTTP_AUTHORIZATION' => bad_credentials }
        post "/api/v1/documents", valid_params, valid_session
      end

      it 'returns error message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 400, "developer_message" => "Unauthorized"))
      end
    end

    context 'something terrible happens' do
      before do
        allow(Document).to receive(:create) { raise_error(Exception) }
        valid_params = { "document_id" => "a1234", "title" => "my title", "path" => "http://www.gov.gov/goo.html", "created" => "2013-02-27T10:00:00Z", "description" => "my desc", "promote" => true }
        post "/api/v1/documents", valid_params, valid_session
      end

      it 'returns failure message as JSON' do
        expect(response.status).to eq(500)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 500, "developer_message" => "Something unexpected happened and we've been alerted."))
      end
    end

  end

  describe "PUT /api/v1/documents/{document_id}" do
    context 'success case' do
      before do
        Elasticsearch::Persistence.client.delete_by_query index: Document.index_name, q: '*:*'
        Document.create(_id: "mycms_124", language: 'en', title: "hi there 4", description: 'bigger desc 4', content: "huge content 4", created: 2.hours.ago, updated: Time.now, promote: true, path: "http://www.gov.gov/url4.html")
        valid_params = { "title" => "my title",
                         "description" => "new desc",
                         "content" => "new content",
                         "path" => "http://www.next.gov/updated.html",
                         "promote" => false }
        put "/api/v1/documents/mycms_124", valid_params, valid_session
        Document.refresh_index!
      end

      it 'returns success message as JSON' do
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 200, "developer_message" => "OK", "user_message" => "Your document was successfully updated."))
      end

      it 'updates the document' do
        document = Document.find("mycms_124")
        expect(document.path).to eq("http://www.next.gov/updated.html")
        expect(document.promote).to be_falsey
        expect(document.title).to eq('my title')
        expect(document.description).to eq('new desc')
        expect(document.content).to eq('new content')
      end

    end
  end

  describe "DELETE /api/v1/documents/{document_id}" do
    context 'success case' do
      before do
        Elasticsearch::Persistence.client.delete_by_query index: Document.index_name, q: '*:*'
        Document.create(_id: "mycms_124", language: 'en', title: "hi there 4", description: 'bigger desc 4', content: "huge content 4", created: 2.hours.ago, updated: Time.now, promote: true, path: "http://www.gov.gov/url4.html")
        delete "/api/v1/documents/mycms_124", nil, valid_session
      end

      it 'returns success message as JSON' do
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 200, "developer_message" => "OK", "user_message" => "Your document was successfully deleted."))
      end

      it 'deletes the document' do
        expect(Document.exists?("mycms_124")).to be_falsey
      end

    end
  end
end