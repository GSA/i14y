module API
  module V1
    class Collections < Grape::API
      prefix 'api'
      version 'v1'
      default_format :json
      format :json
      rescue_from Grape::Exceptions::ValidationErrors do |e|
        rack_response({ developer_message: e.message, status: 400 }.to_json, 400)
      end

      http_basic do |admin_user, admin_password|
        error_hash = { developer_message: "Unauthorized", status: 400 }
        error!(error_hash, 400) unless auth?(admin_user, admin_password)
        true
      end

      helpers do
        def ok(user_message)
          { status: 200, developer_message: "OK", user_message: user_message }
        end

        def auth?(admin_user, admin_password)
          yaml = YAML.load_file("#{Rails.root}/config/secrets.yml")
          env_secrets = yaml[Rails.env]
          admin_user == env_secrets['admin_user'] && admin_password == env_secrets['admin_password']
        end

      end

      resource :collections do
        desc "Create a collection"
        params do
          requires :handle,
                   allow_blank: false,
                   type: String,
                   regexp: %r(^[a-z0-9._]+$),
                   desc: "Immutable name of the logical index used when authenticating Document API calls"
          requires :token,
                   type: String,
                   allow_blank: false,
                   desc: "Token to be used when authenticating Document API calls"
        end
        post do
          handle = params[:handle]
          collection = Collection.create(_id: handle, token: params[:token])
          error!(collection.errors.messages, 400) unless collection.valid?
          es_documents_index_name = [Document.index_namespace(handle), 'v1'].join('-')
          Document.create_index!(index: es_documents_index_name)
          Elasticsearch::Persistence.client.indices.put_alias index: es_documents_index_name,
                                                              name: Document.index_namespace(handle)
          ok("Your collection was successfully created.")
        end

        desc "Delete a collection"
        delete ':handle' do
          handle = params.delete(:handle)
          collection = Collection.find(handle)
          error!(collection.errors.messages, 400) unless collection.destroy
          Elasticsearch::Persistence.client.indices.delete(index: [Document.index_namespace(handle), '*'].join('-'))
          ok("Your collection was successfully deleted.")
        end

        desc 'Search for documents in collections'
        params do
          requires :handles,
                   allow_blank: false,
                   type: String,
                   desc: "Restrict results to this comma-separated list of document collections"
          requires :language,
                   type: Symbol,
                   values: SUPPORTED_LOCALES,
                   allow_blank: false,
                   desc: "Restrict results to documents in a particular language"
          requires :query,
                   allow_blank: false,
                   type: String,
                   desc: "Search term. See documentation on supported query syntax."
          optional :size,
                   allow_blank: false,
                   type: Integer,
                   default: 20,
                   values: 1..100,
                   desc: "Number of results to return"
          optional :offset,
                   allow_blank: false,
                   type: Integer,
                   default: 0,
                   values: 0..1000,
                   desc: "Offset of results"
        end
        get :search do
          handles = params.delete(:handles).split(',')
          valid_collections = Collection.find(handles).compact
          error!("Could not find all the specified collection handles", 400) unless valid_collections.size == handles.size
          document_search = DocumentSearch.new(params.merge(handles: valid_collections.collect(&:id)))
          document_search_results = document_search.search
          metadata_hash = { total: document_search_results.total, offset: document_search_results.offset, suggestion: document_search_results.suggestion }
          { status: 200, developer_message: "OK", metadata: metadata_hash, results: document_search_results.results }
        end

        desc "Get collection info and stats"
        get ':handle' do
          handle = params.delete(:handle)
          collection = Collection.find(handle)
          { status: 200, developer_message: "OK"}.merge(collection.as_json(root: true, methods: [:document_total, :last_document_sent]))
        end
      end
    end
  end
end