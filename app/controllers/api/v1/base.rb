module Api
  module V1
    class Base < Grape::API
      mount Api::V1::Documents
      mount Api::V1::Collections
    end
  end
end
