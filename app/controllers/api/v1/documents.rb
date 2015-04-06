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

      http_basic do |index_handle, index_key|
        error_hash = { developer_message: "Unauthorized", status: 400 }
        error!(error_hash, 400) unless index_handle == 'test_index' && index_key == 'test_key'
        true
      end

      helpers do
        def ok(user_message)
          { status: 200, developer_message: "OK", user_message: user_message }
        end
      end

      resource :documents do
        desc "Create a document"
        params do
          requires :document_id,
                   type: String,
                   desc: "User-assigned document ID"
          requires :title,
                   type: String,
                   desc: "Document title"
          requires :path,
                   type: String,
                   desc: "Document link URL"
          requires :created,
                   type: DateTime,
                   desc: "When document was initially created",
                   documentation: { example: '2013-02-27T10:00:00Z' }
          optional :description,
                   type: String,
                   desc: "Document description"
          optional :content,
                   type: String,
                   desc: "Document content/body"
          optional :changed,
                   type: DateTime,
                   desc: "When document was modified",
                   documentation: { example: '2013-02-27T10:00:01Z' }
          optional :promote,
                   type: Boolean,
                   desc: "Whether to promote the document in the relevance ranking"
          at_least_one_of :content, :description
        end
        post do
          ok("Your document was successfully created.")
        end

        desc "Update a document"
        params do
          optional :title, type: String, desc: "Document title"
          optional :path, type: String, desc: "Document link URL"
          optional :created, type: DateTime, desc: "When document was initially created"
          optional :description, type: String, desc: "Document description"
          optional :content, type: String, desc: "Document content/body"
          optional :changed, type: DateTime, desc: "When document was modified"
          optional :promote, type: Boolean, desc: "Whether to promote the document in the relevance ranking"
          at_least_one_of :title, :path, :created, :content, :description, :changed, :promote
        end
        put ':document_id' do
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