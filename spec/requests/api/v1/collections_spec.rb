require 'rails_helper'

describe API::V1::Collections do
  let(:valid_session) do
    yaml = YAML.load_file("#{Rails.root}/config/secrets.yml")
    env_secrets = yaml[Rails.env]
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials env_secrets['admin_user'], env_secrets['admin_password']
    { 'HTTP_AUTHORIZATION' => credentials }
  end

  describe "POST /api/v1/collections" do
    context 'success case' do
      before do
        Elasticsearch::Persistence.client.delete_by_query index: Collection.index_name, q: '*:*'
        valid_params = { "handle" => "agency_blogs", "token" => "secret" }
        post "/api/v1/collections", valid_params, valid_session
        Collection.refresh_index!
      end

      it 'returns success message as JSON' do
        expect(response.status).to eq(201)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 200, "developer_message" => "OK", "user_message" => "Your collection was successfully created."))
      end

      it 'uses the collection handle as the Elasticsearch ID' do
        expect(Collection.find("agency_blogs")).to be_present
      end

      it 'stores the appropriate fields in the Elasticsearch collection' do
        collection = Collection.find("agency_blogs")
        expect(collection.token).to eq("secret")
      end
    end

    context 'a required parameter is empty/blank' do
      before do
        invalid_params = {}
        post "/api/v1/collections", invalid_params, valid_session
      end

      it 'returns failure message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 400, "developer_message" => "handle is missing, handle is empty, handle is invalid, token is missing, token is empty"))
      end
    end

    context 'handle uses illegal characters' do
      before do
        invalid_params = { "handle" => "agency-blogs", "token" => "secret" }
        post "/api/v1/collections", invalid_params, valid_session
      end

      it 'returns failure message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 400, "developer_message" => "handle is invalid"))
      end
    end

    context 'failed authentication/authorization' do
      before do
        valid_params = { "handle" => "agency_blogs", "token" => "secret" }
        bad_credentials = ActionController::HttpAuthentication::Basic.encode_credentials "nope", "wrong"

        valid_session = { 'HTTP_AUTHORIZATION' => bad_credentials }
        post "/api/v1/collections", valid_params, valid_session
      end

      it 'returns error message as JSON' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 400, "developer_message" => "Unauthorized"))
      end
    end

    context 'something terrible happens' do
      before do
        allow(Collection).to receive(:create) { raise_error(Exception) }
        valid_params = { "handle" => "agency_blogs", "token" => "secret" }
        post "/api/v1/collections", valid_params, valid_session
      end

      it 'returns failure message as JSON' do
        expect(response.status).to eq(500)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 500, "developer_message" => "Something unexpected happened and we've been alerted."))
      end
    end

  end
  
  describe "DELETE /api/v1/collections/{handle}" do
    context 'success case' do
      before do
        Elasticsearch::Persistence.client.delete_by_query index: Collection.index_name, q: '*:*'
        Collection.create(_id: "agency_blogs", token: "secret")
        delete "/api/v1/collections/agency_blogs", nil, valid_session
      end

      it 'returns success message as JSON' do
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to match(hash_including('status' => 200, "developer_message" => "OK", "user_message" => "Your collection was successfully deleted."))
      end

      it 'deletes the collection' do
        expect(Collection.exists?("agency_blogs")).to be_falsey
      end

    end
  end
end