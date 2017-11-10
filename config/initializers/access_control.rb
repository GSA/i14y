yaml = YAML.load_file("#{Rails.root}/config/access_control.yml") rescue { }
I14y::Application.config.updates_allowed = !!yaml['updates_allowed']
