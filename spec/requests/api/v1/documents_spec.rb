require 'rails_helper'

describe API::V1::Documents do
  let(:valid_session) do
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials "test_index", "test_key"
    { 'HTTP_AUTHORIZATION' => credentials }
  end

  describe "POST /api/v1/documents" do
    context 'success case' do
      before do
        valid_params = { "document_id" => "a1234", "title" => "my title", "path" => "http://www.gov.gov/goo.html", "created" => "2013-02-27T10:00:00Z", "description" => "my desc", "promote" => true }
        post "/api/v1/documents", valid_params, valid_session
      end

      it 'returns success message as JSON' do
        expect(response.status).to eq(201)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 200, "developer_message" => "OK", "user_message" => "Your document was successfully created."))
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

    xcontext 'something terrible happens' do
      before do
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
        valid_params = {"title" => "my title" }
        put "/api/v1/documents/a1234", valid_params, valid_session
      end

      it 'returns success message as JSON' do
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 200, "developer_message" => "OK", "user_message" => "Your document was successfully updated."))
      end

    end
  end

  describe "DELETE /api/v1/documents/{document_id}" do
    context 'success case' do
      before do
        delete "/api/v1/documents/a1234", nil, valid_session
      end

      it 'returns success message as JSON' do
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 200, "developer_message" => "OK", "user_message" => "Your document was successfully deleted."))
      end

    end
  end
end