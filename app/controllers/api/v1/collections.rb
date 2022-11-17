module Api
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
        error_hash = { developer_message: 'Unauthorized', status: 400 }
        error!(error_hash, 400) unless auth?(admin_user, admin_password)
        true
      end

      helpers ReadOnlyAccessControl

      helpers do
        def ok(user_message)
          { status: 200, developer_message: 'OK', user_message: user_message }
        end

        def auth?(admin_user, admin_password)
          yaml = YAML.load_file("#{Rails.root}/config/secrets.yml")
          env_secrets = yaml[Rails.env]
          admin_user == env_secrets['admin_user'] && admin_password == env_secrets['admin_password']
        end
      end

      resource :collections do
        desc 'Create a collection'
        params do
          requires :handle,
                   allow_blank: false,
                   type: String,
                   regexp: /^[a-z0-9._]+$/,
                   desc: 'Immutable name of the logical index used when authenticating Document API calls'
          requires :token,
                   type: String,
                   allow_blank: false,
                   desc: 'Token to be used when authenticating Document API calls'
        end
        post do
          check_updates_allowed
          handle = params[:handle]
          collection = Collection.new(id: handle, token: params[:token])
          error!(collection.errors.messages, 400) unless collection.valid?
          ES.collection_repository.save(collection)
          documents_index_name = [DocumentRepository.index_namespace(handle), 'v1'].join('-')
          DocumentRepository.new.create_index!(
            index: documents_index_name,
            include_type_name: true
          )
          ES.client.indices.put_alias(
            index: documents_index_name,
            name: DocumentRepository.index_namespace(handle)
          )
          ok('Your collection was successfully created.')
        end

        desc 'Delete a collection'
        delete ':handle' do
          check_updates_allowed
          handle = params.delete(:handle)
          collection = ES.collection_repository.find(handle)
          error!(collection.errors.messages, 400) unless ES.collection_repository.delete(handle)
          ES.client.indices.delete(
            index: [DocumentRepository.index_namespace(handle), '*'].join('-')
          )
          ok('Your collection was successfully deleted.')
        end

        desc 'Search for documents in collections'
        params do
          requires :handles,
                   allow_blank: false,
                   type: String,
                   desc: 'Restrict results to this comma-separated list of document collections'
          optional :language,
                   type: Symbol,
                   values: SUPPORTED_LOCALES,
                   allow_blank: false,
                   desc: 'Restrict results to documents in a particular language'
          optional :query,
                   allow_blank: true,
                   type: String,
                   desc: 'Search term. See documentation on supported query syntax.'
          optional :size,
                   allow_blank: false,
                   type: Integer,
                   default: 20,
                   values: 1..1000,
                   desc: 'Number of results to return'
          optional :offset,
                   allow_blank: false,
                   type: Integer,
                   default: 0,
                   desc: 'Offset of results'
          optional :min_timestamp,
                   type: DateTime,
                   allow_blank: false,
                   desc: 'Return documents that were changed at or after this time',
                   documentation: { example: '2013-02-27T10:00:00Z' }
          optional :max_timestamp,
                   type: DateTime,
                   allow_blank: false,
                   desc: 'Return documents that were changed before this time',
                   documentation: { example: '2013-02-27T10:01:00Z' }
          optional :min_timestamp_created,
                   type: DateTime,
                   allow_blank: false,
                   desc: 'Return documents that were created at or after this time',
                   documentation: { example: '2013-02-27T10:00:00Z' }
          optional :max_timestamp_created,
                   type: DateTime,
                   allow_blank: false,
                   desc: 'Return documents that were created before this time',
                   documentation: { example: '2013-02-27T10:01:00Z' }
          optional :sort_by_date,
                   type: Boolean,
                   desc: 'Whether to order documents by created date instead of relevance'
          optional :tags,
                   type: String,
                   allow_blank: false,
                   desc: 'Comma-separated list of category tags'
          optional :ignore_tags,
                   type: String,
                   allow_blank: false,
                   desc: 'Comma-separated list of category tags to exclude'
          optional :include,
                   type: String,
                   allow_blank: false,
                   desc: 'Comma-separated list of fields to include in results',
                   documentation: { example: 'title,path,description,content,updated_at' }
        end
        get :search do
          handles = params.delete(:handles).split(',')
          valid_collections = ES.collection_repository.find(handles).compact
          error!('Could not find all the specified collection handles', 400) unless valid_collections.size == handles.size
          %i[tags ignore_tags include].each { |key| params[key] = params[key].extract_array if params[key].present? }
          document_search = DocumentSearch.new(params.merge(handles: valid_collections.collect(&:id)))
          document_search_results = document_search.search
          metadata_hash = { total: document_search_results.total,
                            offset: document_search_results.offset,
                            suggestion: document_search_results.suggestion,
                            aggregations: document_search_results.aggregations }
          { status: 200, developer_message: 'OK', metadata: metadata_hash, results: document_search_results.results }
        end

        desc 'Get collection info and stats'
        get ':handle' do
          handle = params.delete(:handle)
          collection = ES.collection_repository.find(handle)
          { status: 200, developer_message: 'OK' }.merge(collection.as_json(root: true, methods: [:document_total, :last_document_sent]))
        end
      end
    end
  end
end
