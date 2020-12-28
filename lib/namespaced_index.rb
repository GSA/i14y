# frozen_string_literal: true

module NamespacedIndex
  def index_namespace(handle = nil)
    [Rails.env, I14y::APP_NAME, klass.to_s.tableize, handle].compact.join('-')
  end
end
