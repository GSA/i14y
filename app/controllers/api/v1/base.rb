module API
  module V1
    class Base < Grape::API
      mount API::V1::Documents
      mount API::V1::Collections
    end
  end
end