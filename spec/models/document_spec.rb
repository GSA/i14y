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

  context 'language fields contain HTML/CSS and HTML entities' do
    before do
      html = %[
  <div style="height: 100px; width: 100px;"></div>
  <p>hello & goodbye!</p>
]
      Document.create(_id: 'a123', language: 'en', title: '<b><a href="http://foo.com/">foo</a></b><img src="bar.jpg">', description: html, created: DateTime.now, path: 'http://www.agency.gov/page1.html', content: "this <b>is</b> <a href='http://gov.gov/url.html'>html</a>")
    end

    after do
      Document.find('a123').delete
    end

    it 'sanitizes the language fields' do
      document = Document.find 'a123'
      expect(document.title).to eq("foo")
      expect(document.description).to eq("hello & goodbye!")
      expect(document.content).to eq("this is html")
    end
  end

  context 'computed fields' do
    before do
      Document.create(_id: 'b123', language: 'en', title: 'title', content: 'content', created: DateTime.now, path: 'http://www.agency.gov/page1.htmlol')
      Document.refresh_index!(index: [Document.index_namespace('test_index'), '*'].join('-'))
    end

    after do
      Document.find('b123').delete
    end

    it 'extracts basename from path' do
      document = Document.search(query: { match: { basename: 'page1' } }).first
      expect(document.id).to eq('b123')
    end

    it 'extracts extension from path' do
      document = Document.search(query: { match: { extension: 'htmlol' } }).first
      expect(document.id).to eq('b123')
    end

    it 'extracts url_path from path' do
      document = Document.search(query: { match: { url_path: '/page1.htmlol' } }).first
      expect(document.id).to eq('b123')
    end

    it 'extracts domain_name from path' do
      document = Document.search(query: { match: { domain_name: 'www.agency.gov' } }).first
      expect(document.id).to eq('b123')
    end
  end
end
