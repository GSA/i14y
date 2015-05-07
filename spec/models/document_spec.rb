require 'rails_helper'

describe Document do
  before(:all) do
    handle = 'test_index'
    Elasticsearch::Persistence.client.indices.delete(index: [Document.index_namespace(handle), '*'].join('-'))
    es_documents_index_name = [Document.index_namespace(handle), 'v1'].join('-')
    Document.create_index!(index: es_documents_index_name)
    Elasticsearch::Persistence.client.indices.put_alias index: es_documents_index_name,
                                                        name: Document.index_namespace(handle)
    Document.index_name = Document.index_namespace(handle)
  end

  after(:all) do
    Elasticsearch::Persistence.client.indices.delete(index: [Document.index_namespace('test_index'), '*'].join('-'))
  end

  context 'language fields contain HTML/CSS' do
    before do
      html = %[
  <div style="height: 100px; width: 100px;"></div>
  <p>hello!</p>
]
      Document.create(_id: 'a123', language: 'en', title: '<b><a href="http://foo.com/">foo</a></b><img src="bar.jpg">', description: html, created: DateTime.now, path: 'http://www.agency.gov/page1.html', content: "this <b>is</b> <a href='http://gov.gov/url.html'>html</a>")
    end

    it 'sanitizes the language fields' do
      document = Document.find 'a123'
      expect(document.title).to eq("foo")
      expect(document.description).to eq("hello!")
      expect(document.content).to eq("this is html")
    end
  end
end