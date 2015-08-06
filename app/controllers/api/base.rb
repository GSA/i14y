module API
  class Base < Grape::API
    rescue_from Elasticsearch::Persistence::Repository::DocumentNotFound do |e|
      rack_response({ developer_message: "Resource could not be found.", status: 400 }.to_json, 400)
    end

    rescue_from :all do |e|
      Rails.logger.error "#{e}\n\n#{e.backtrace.join("\n")}"

      Airbrake.notify(e)

      rack_response({ developer_message: "Something unexpected happened and we've been alerted.", status: 500 }.to_json, 500)
    end

    mount API::V1::Base
  end
end