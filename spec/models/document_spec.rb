require 'rails_helper'

describe Document do
  let(:valid_params) do
    {
      _id: 'a123',
      language: 'en',
      path: 'http://www.agency.gov/page1.html',
      title: 'My Title',
      created: DateTime.now,
      changed: DateTime.now,
      description: 'My Description',
      content: 'some content',
      promote: true,
      tags: 'this,that'
    }
  end

  before(:all) do
    handle = 'test_index'
    Elasticsearch::Persistence.client.indices.delete(
      index: [Document.index_namespace(handle), '*'].join('-')
    )
    es_documents_index_name = [Document.index_namespace(handle), 'v1'].join('-')
    Document.create_index!(index: es_documents_index_name)
    Elasticsearch::Persistence.client.indices.put_alias index: es_documents_index_name,
                                                        name: Document.index_namespace(handle)
    Document.index_name = Document.index_namespace(handle)
  end

  after(:all) do
    Elasticsearch::Persistence.client.indices.delete(
      index: [Document.index_namespace('test_index'), '*'].join('-')
    )
  end

  describe '.create' do
    context 'when language fields contain HTML/CSS and HTML entities' do
      let(:html) do
        <<~HTML
          <div style="height: 100px; width: 100px;"></div>
          <p>hello & goodbye!</p>
        HTML
      end

      before do
        Document.create(_id: 'a123',
                        language: 'en',
                        title: '<b><a href="http://foo.com/">foo</a></b><img src="bar.jpg">',
                        description: html,
                        created: DateTime.now,
                        path: 'http://www.agency.gov/page1.html',
                        content: "this <b>is</b> <a href='http://gov.gov/url.html'>html</a>")
      end

      it 'sanitizes the language fields' do
        document = Document.find 'a123'
        expect(document.title).to eq('foo')
        expect(document.description).to eq('hello & goodbye!')
        expect(document.content).to eq('this is html')
      end
    end

    context 'when a created value is provided but not changed' do
      let(:params_without_changed) do
        valid_params.merge(created: DateTime.now, changed: '')
      end

      before { Document.create(params_without_changed) }

      it 'sets "changed" to be the same as "created"' do
        Document.create(params_without_changed)
        document = Document.find('a123')
        expect(document.changed).to eq document.created
      end
    end
  end
end
