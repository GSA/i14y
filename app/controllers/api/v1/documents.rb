module Api
  module V1
    class Documents < Grape::API
      prefix 'api'
      version 'v1'
      default_format :json
      format :json

      # Eventually, the validation logic should all be moved to the model classes,
      # and the validation itself should happen during serialization:
      # https://www.elastic.co/blog/activerecord-to-repository-changing-persistence-patterns-with-the-elasticsearch-rails-gem
      rescue_from Grape::Exceptions::ValidationErrors do |e|
        rack_response({ developer_message: e.message, status: 400 }.to_json, 400)
      end
      rescue_from Elasticsearch::Transport::Transport::Errors::Conflict do |_e|
        rack_response({ developer_message: 'Document already exists with that ID', status: 422 }.to_json, 422)
      end

      http_basic do |collection_handle, token|
        error_hash = { developer_message: 'Unauthorized', status: 400 }
        error!(error_hash, 400) unless auth?(collection_handle, token)
        @collection_handle = collection_handle
        true
      end

      helpers ReadOnlyAccessControl

      helpers do
        def ok(user_message)
          { status: 200, developer_message: 'OK', user_message: user_message }
        end

        def auth?(collection_handle, token)
          ES.collection_repository.find(collection_handle).token == token
        rescue Elasticsearch::Persistence::Repository::DocumentNotFound,
               Elasticsearch::Transport::Transport::Errors::BadRequest
          false
        end

        def document_repository
          index_name = params[:index_name] || DocumentRepository.index_namespace(@collection_handle)
          DocumentRepository.new(index_name: index_name)
        end
      end

      before do
        check_updates_allowed
      end

      resource :documents do
        desc 'Create a document'
        params do
          requires :document_id,
                   allow_blank: false,
                   type: String,
                   regexp: { value: %r{^[^/]+$}, message: "cannot contain any of the following characters: ['/']" },
                   max_bytes: 512,
                   desc: 'User-assigned document ID'
          requires :title,
                   type: String,
                   allow_blank: false,
                   desc: 'Document title'
          requires :path,
                   type: String,
                   allow_blank: false,
                   regexp: %r{^https?://[^\s/$.?#].[^\s]*$},
                   desc: 'Document link URL'
          optional :audience,
                   type: String,
                   allow_blank: false,
                   desc: 'Document audience'
          optional :changed,
                   type: DateTime,
                   allow_blank: false,
                   desc: 'When document was modified',
                   documentation: { example: '2013-02-27T10:00:01Z' }
          optional :content,
                   type: String,
                   allow_blank: false,
                   desc: 'Document content/body'
          optional :content_type,
                   type: String,
                   allow_blank: false,
                   desc: 'Document content type'
          optional :created,
                   type: DateTime,
                   allow_blank: true,
                   desc: 'When document was initially created',
                   documentation: { example: '2013-02-27T10:00:00Z' }
          optional :description,
                   type: String,
                   allow_blank: false,
                   desc: 'Document description'
          optional :thumbnail_url,
                   type: String,
                   allow_blank: false,
                   desc: 'Document thumbnail_url'
          optional :language,
                   type: Symbol,
                   values: SUPPORTED_LOCALES,
                   default: :en,
                   allow_blank: false,
                   desc: 'Two-letter locale describing language of document (defaults to :en)'
          optional :mime_type,
                   type: String,
                   allow_blank: false,
                   desc: 'Document MIME type'
          optional :promote,
                   type: Boolean,
                   desc: 'Whether to promote the document in the relevance ranking'
          optional :searchgov_custom1,
                   type: String,
                   allow_blank: false,
                   desc: 'Document custom field 1'
          optional :searchgov_custom2,
                   type: String,
                   allow_blank: false,
                   desc: 'Document custom field 2'
          optional :searchgov_custom3,
                   type: String,
                   allow_blank: false,
                   desc: 'Document custom field 3'
          optional :tags,
                   type: String,
                   allow_blank: false,
                   desc: 'Comma-separated list of category tags'
        end

        post do
          id = params.delete(:document_id)
          document = Document.new(params.merge(id: id))
          error!({ developer_message: document.errors.full_messages.join(', '), status: 400 }, 400) if document.invalid?
          document_repository.save(document, op_type: :create)
          ok('Your document was successfully created.')
        end

        desc 'Update a document'
        params do
          optional :index_name,
                   type: String,
                   allow_blank: false,
                   desc: 'Elasticsearch index name for the document'
          optional :title,
                   type: String,
                   allow_blank: false,
                   desc: 'Document title'
          optional :path,
                   type: String,
                   allow_blank: false,
                   regexp: %r{^https?://[^\s/$.?#].[^\s]*$},
                   desc: 'Document link URL'
          optional :audience,
                   type: String,
                   allow_blank: false,
                   desc: 'Document audience'
          optional :changed,
                   type: DateTime,
                   allow_blank: false,
                   desc: 'When document was modified',
                   documentation: { example: '2013-02-27T10:00:01Z' }
          optional :click_count,
                   type: Integer,
                   allow_blank: false,
                   desc: 'Count of clicks'
          optional :content,
                   type: String,
                   allow_blank: false,
                   desc: 'Document content/body'
          optional :content_type,
                   type: String,
                   allow_blank: false,
                   desc: 'Document content type'
          optional :created,
                   type: DateTime,
                   allow_blank: true,
                   desc: 'When document was initially created',
                   documentation: { example: '2013-02-27T10:00:00Z' }
          optional :description,
                   type: String,
                   allow_blank: false,
                   desc: 'Document description'
          optional :thumbnail_url,
                   type: String,
                   allow_blank: false,
                   desc: 'Document thumbnail_url'
          optional :language,
                   type: Symbol,
                   values: SUPPORTED_LOCALES,
                   allow_blank: false,
                   desc: 'Two-letter locale describing language of document'
          optional :mime_type,
                   type: String,
                   allow_blank: false,
                   desc: 'Document MIME type'
          optional :promote,
                   type: Boolean,
                   desc: 'Whether to promote the document in the relevance ranking'
          optional :searchgov_custom1,
                   type: String,
                   allow_blank: false,
                   desc: 'Document custom field 1'
          optional :searchgov_custom2,
                   type: String,
                   allow_blank: false,
                   desc: 'Document custom field 2'
          optional :searchgov_custom3,
                   type: String,
                   allow_blank: false,
                   desc: 'Document custom field 3'
          optional :tags,
                   type: String,
                   allow_blank: false,
                   desc: 'Comma-separated list of category tags'

          at_least_one_of :audience,
                          :changed,
                          :click_count,
                          :content,
                          :content_type,
                          :created,
                          :description,
                          :document_id,
                          :handle,
                          :thumbnail_url,
                          :language,
                          :mime_type,
                          :path,
                          :promote,
                          :searchgov_custom1,
                          :searchgov_custom2,
                          :searchgov_custom3,
                          :tags,
                          :title
        end

        put ':document_id', requirements: { document_id: /.*/ } do
          id = params.delete(:document_id)
          # SRCH-5096 Ensure that existing attributes are not overwritten on put or else the weekly
          # searchgov ClickMonitorJob and (infrequent) `searchgov:promote` task will delete metadata
          document = document_repository.find(id, _source: %w[audience
                                                              changed
                                                              content_type
                                                              created
                                                              created_at
                                                              language
                                                              mime_type
                                                              path
                                                              searchgov_custom1
                                                              searchgov_custom2
                                                              searchgov_custom3
                                                              tags])
          document.attributes = document.attributes.merge(params)
          error!({ developer_message: document.errors.full_messages.join(', '), status: 400 }, 400) if document.invalid?
          document_repository.update(document)
          ok('Your document was successfully updated.')
        end

        desc 'Delete a document'
        delete ':document_id', requirements: { document_id: /.*/ } do
          id = params[:document_id]
          error!(document.errors.messages, 400) unless document_repository.delete(id)
          ok('Your document was successfully deleted.')
        end
      end
    end
  end
end
