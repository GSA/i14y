config = Rails.application.config_for(:access_control)
I14y::Application.config.updates_allowed = !!config['updates_allowed']
