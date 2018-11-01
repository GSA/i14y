module DocumentCrud

  def document_create(params)
    Document.create(params)
    Document.refresh_index!
  end

  def api_post(params,session)
    post "/api/v1/documents", params: params, headers: session
    Document.refresh_index!
  end

  def api_put(path,params, session)
    put path, params: params, headers: session
    Document.refresh_index!
  end

  def api_delete(path,session)
    delete path, headers: session
  end

end
