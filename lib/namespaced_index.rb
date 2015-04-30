module NamespacedIndex
  def index_namespace(handle = nil)
    [Rails.env, APP_NAME, self.name.tableize, handle].compact.join('-')
  end

end