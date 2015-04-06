module API
  class Base < Grape::API
    rescue_from :all do |e|
      Rails.logger.error "#{e}\n\n#{e.backtrace.join("\n")}"

      Airbrake.notify(e)

      rack_response({ developer_message: "Something unexpected happened and we've been alerted.", status: 500 }, 500)
    end

    mount API::V1::Base
  end
end