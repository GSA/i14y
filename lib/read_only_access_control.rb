module ReadOnlyAccessControl
  class DisallowedUpdate < StandardError; end

  def check_updates_allowed
    raise DisallowedUpdate unless I14y::Application.config.updates_allowed
  end
end
