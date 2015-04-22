module API
  module V1
    class Documents < Grape::API
      prefix 'api'
      version 'v1'
      default_format :json
      format :json
      rescue_from Grape::Exceptions::ValidationErrors do |e|
        rack_response({ developer_message: e.message, status: 400 }.to_json, 400)
      end

      http_basic do |collection_handle, token|
        error_hash = { developer_message: "Unauthorized", status: 400 }
        error!(error_hash, 400) unless collection_handle == 'test_index' && token == 'test_key'
        @collection_handle = collection_handle
        true
      end

      helpers do
        def ok(user_message)
          { status: 200, developer_message: "OK", user_message: user_message }
        end

        def id_from(document_id)
          [@collection_handle, document_id].join(':')
        end
      end

      resource :documents do
        desc "Create a document"
        params do
          requires :document_id,
                   allow_blank: false,
                   type: String,
                   desc: "User-assigned document ID"
          requires :title,
                   type: String,
                   allow_blank: false,
                   desc: "Document title"
          requires :path,
                   type: String,
                   allow_blank: false,
                   regexp: %r(^https?:\/\/[^\s\/$.?#].[^\s]*$),
                   desc: "Document link URL"
          requires :created,
                   type: DateTime,
                   allow_blank: false,
                   desc: "When document was initially created",
                   documentation: { example: '2013-02-27T10:00:00Z' }
          optional :description,
                   type: String,
                   allow_blank: false,
                   desc: "Document description"
          optional :content,
                   type: String,
                   allow_blank: false,
                   desc: "Document content/body"
          optional :changed,
                   type: DateTime,
                   allow_blank: false,
                   desc: "When document was modified",
                   documentation: { example: '2013-02-27T10:00:01Z' }
          optional :promote,
                   type: Boolean,
                   desc: "Whether to promote the document in the relevance ranking"
          optional :language,
                   type: Symbol,
                   values: SUPPORTED_LOCALES,
                   default: :en,
                   allow_blank: false,
                   desc: "Two-letter locale describing language of document (defaults to :en)"

          at_least_one_of :content, :description
        end
        post do
          document = Document.create(params.merge(collection_handle: @collection_handle, _id: id_from(params[:document_id])))
          error!(document.errors.messages, 400) unless document.valid?
          ok("Your document was successfully created.")
        end

        desc "Update a document"
        params do
          optional :title,
                   type: String,
                   allow_blank: false,
                   desc: "Document title"
          optional :path,
                   type: String,
                   allow_blank: false,
                   regexp: %r(^https?:\/\/[^\s\/$.?#].[^\s]*$),
                   desc: "Document link URL"
          optional :created,
                   type: DateTime,
                   allow_blank: false,
                   desc: "When document was initially created",
                   documentation: { example: '2013-02-27T10:00:00Z' }
          optional :description,
                   type: String,
                   allow_blank: false,
                   desc: "Document description"
          optional :content,
                   type: String,
                   allow_blank: false,
                   desc: "Document content/body"
          optional :changed,
                   type: DateTime,
                   allow_blank: false,
                   desc: "When document was modified",
                   documentation: { example: '2013-02-27T10:00:01Z' }
          optional :promote,
                   type: Boolean,
                   desc: "Whether to promote the document in the relevance ranking"
          optional :language,
                   type: Symbol,
                   values: SUPPORTED_LOCALES,
                   allow_blank: false,
                   desc: "Two-letter locale describing language of document"
          at_least_one_of :title, :path, :created, :content, :description, :changed, :promote, :language
        end
        put ':document_id' do
          document_id = params.delete(:document_id)
          document = Document.find(id_from(document_id))
          title = params.delete :title
          params.store("title_#{document.language}", title) if title.present?

          document.update(params)
          error!(document.errors.messages, 400) unless document.update(params)
          ok("Your document was successfully updated.")
        end

        desc "Delete a document"
        delete ':document_id' do
          ok("Your document was successfully deleted.")
        end
      end
    end
  end
end