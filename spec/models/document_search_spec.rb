require 'rails_helper'

describe DocumentSearch do

  before do
    Elasticsearch::Persistence.client.indices.delete(index: [Document.index_namespace('agency_blogs'), '*'].join('-'))
    es_documents_index_name = [Document.index_namespace('agency_blogs'), 'v1'].join('-')
    Document.create_index!(index: es_documents_index_name)
    Elasticsearch::Persistence.client.indices.put_alias index: es_documents_index_name,
                                                        name: Document.index_namespace('agency_blogs')
    Document.index_name = Document.index_namespace('agency_blogs')
  end

  context 'searching across a single index collection' do
    context 'matching documents exist' do
      before do
        Document.create( language: 'en', title: 'title 1 common content', description: 'description 1 common content', created: DateTime.now, path: 'http://www.agency.gov/page1.html')
        Document.refresh_index!
      end

      it 'returns results' do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "common")
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
      end
    end

    context 'no matching documents exist' do
      it 'returns no results ' do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "common")
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(0)
      end
    end

  end

  context 'searching across multiple indexes' do
    before do
      Document.create(language: 'en', title: 'title 1 common content', description: 'description 1 common content', created: DateTime.now, path: 'http://www.agency.gov/page1.html')
      Document.refresh_index!
      es_documents_index_name = [Document.index_namespace('other_agency_blogs'), 'v1'].join('-')
      Document.create_index!(index: es_documents_index_name)
      Elasticsearch::Persistence.client.indices.put_alias index: es_documents_index_name,
                                                          name: Document.index_namespace('other_agency_blogs')
      Document.index_name = Document.index_namespace('other_agency_blogs')
      Document.create(language: 'en', title: 'other title 1 common content', description: 'other description 1 common content', created: DateTime.now, path: 'http://www.otheragency.gov/page1.html')
      Document.refresh_index!
    end

    it 'returns results from all indexes' do
      document_search = DocumentSearch.new(handles: %w(agency_blogs other_agency_blogs), language: :en, query: "common")
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(2)
    end
  end

  describe "recall" do
    xit 'matches on words in URL filename'


    context "at least 6/7 query term words are found" do
      before do
        Document.create(language: 'en', title: 'one two three four five six seven', description: 'america description 1', created: DateTime.now, path: 'http://www.agency.gov/page1.html')
        Document.refresh_index!
      end

      it "matches" do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "one two three four five six MISSING")
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
      end
    end
  end

  describe "English relevancy" do
    context 'exact phrase matches' do
      xit 'ranks those higher'
    end

    context 'exact word form matches' do
      xit 'ranks those higher'
    end
  end

  describe "filtering on language" do
    before do
      Document.create(language: 'en', title: 'america title 1', description: 'description 1', created: DateTime.now, path: 'http://www.agency.gov/page1.html')
      Document.create(language: 'fr', title: 'america title 1', description: 'description 1', created: DateTime.now, path: 'http://fr.www.agency.gov/page1.html')
      Document.refresh_index!
    end

    it 'returns results from only that language' do
      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :fr, query: "america")
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)
      expect(document_search_results.results.first['language']).to eq('fr')
    end
  end

  describe "filtering on site:" do


  end
end