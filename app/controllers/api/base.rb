# frozen_string_literal: true

module API
  class Base < Grape::API
    rescue_from ReadOnlyAccessControl::DisallowedUpdate do
      message = 'The i14y API is currently in read-only mode.'
      message += " #{I14y::Application.config.maintenance_message}" if I14y::Application.config.maintenance_message
      rack_response({ developer_message: message, status: 503 }.to_json, 503)
    end

    rescue_from Elasticsearch::Persistence::Repository::DocumentNotFound,
                Elasticsearch::Transport::Transport::Errors::NotFound do |_e|
                  rake_response(
                    { developer_message: 'Resource could not be found.', status: 400 }.to_json,
                    400
                  )
                end

    rescue_from :all do |e|
      Rails.logger.error "#{e}\n\n#{e.backtrace.join("\n")}"

      rack_response({ developer_message: "Something unexpected happened and we've been alerted.", status: 500 }.to_json, 500)
    end

    mount API::V1::Base
  end
end
