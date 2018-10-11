module DocumentCrud
  # Directly calling Elasticsearch
  def document_create(params)
    Document.create(params)
    Document.refresh_index!
  end

  # API CRUD calls
  def api_post(params,session)
    post '/api/v1/documents', params: params, headers: session
    Document.refresh_index!
  end

  def api_delete(path, headers)
    delete path, headers: headers
    Document.refresh_index!
  end

  def api_put(path, params, headers)
    put path, params: params, headers: headers
    Document.refresh_index!
  end
end