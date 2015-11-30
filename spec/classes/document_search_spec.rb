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
        Document.create(language: 'en', title: 'title 1 common content', description: 'description 1 common content', created: DateTime.now, path: 'http://www.agency.gov/page1.html')
        Document.refresh_index!
      end

      it 'returns results' do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "common", size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
      end
    end

    context 'no matching documents exist' do
      it 'returns no results ' do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "common", size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(0)
      end
    end

    context 'something terrible happens during the search' do
      it 'returns a no results response' do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "uh oh", size: 10, offset: 0)
        expect(Elasticsearch::Persistence).to receive(:client).and_return(nil)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(0)
        expect(document_search_results.results).to eq([])
      end
    end

  end

  context 'paginating' do
    before do
      Document.create(language: 'en', title: "most relevant title common content title common content", description: "description common content description common content", created: DateTime.now, path: "http://www.agency.gov/page0.html")
      10.times do |x|
        Document.create(language: 'en', title: "title common content #{x}", description: "description common content #{x}", created: DateTime.now, path: "http://www.agency.gov/page#{x}.html")
      end
      Document.refresh_index!
    end

    it 'returns "size" results' do
      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "common", size: 3, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(11)
      expect(document_search_results.results.size).to eq(3)
    end

    it 'obeys the offset' do
      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "common content", size: 10, offset: 1)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(11)
      expect(document_search_results.results.size).to eq(10)
      document_search_results.results.each do |result|
        expect(result['title']).to start_with('title')
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
      document_search = DocumentSearch.new(handles: %w(agency_blogs other_agency_blogs), language: :en, query: "common", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(2)
    end
  end

  describe "recall" do
    context 'matches on all query terms in URL basename' do
      before do
        Document.create(language: 'en', title: 'The president drops by Housing and Urban Development', description: 'Here he is', created: DateTime.now, path: 'http://www.agency.gov/archives/obama-visits-hud.html')
        Document.refresh_index!
      end

      it "matches" do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "obama hud", size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
      end
    end

    context "enough low frequency and high frequency words are found" do
      before do
        Document.create(language: 'en', title: 'low frequency term', description: 'some description', created: DateTime.now, path: 'http://www.agency.gov/page1.html')
        Document.create(language: 'en', title: 'very rare words', description: 'some other description', created: DateTime.now, path: 'http://www.agency.gov/page1.html')
        80.times do |x|
          Document.create(language: 'en', title: 'high occurrence tokens', description: 'these are like stopwords', created: DateTime.now, path: 'http://www.agency.gov/page1.html')
          Document.create(language: 'en', title: 'showing up everywhere', description: 'these are like stopwords', created: DateTime.now, path: 'http://www.agency.gov/page1.html')
        end
        Document.refresh_index!
      end

      it "matches 3 out of 4 low freq or missing terms" do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "very low frequency term", size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "MISSING low frequency term", size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
      end

      it "matches 2 out of 3 high freq terms" do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "high occurrence everywhere", size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(80)
      end
    end
  end

  describe "overall relevancy" do
    context 'exact phrase matches' do
      before do
        common_params = { language: 'en', created: DateTime.now, path: 'http://www.agency.gov/page1.html',
                          description: 'description' }
        Document.create(common_params.merge(title: 'jefferson township Petitions and Memorials'))
        Document.create(common_params.merge(title: 'jefferson Memorial and township Petitions'))
        Document.refresh_index!
      end

      it 'ranks those higher' do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "jefferson Memorial", size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.results.first['title']).to match(/jefferson Memorial/)
      end
    end

    context 'exact word form matches' do
      before do
        common_params = { language: 'en', created: DateTime.now, path: 'http://www.agency.gov/page1.html',
                          title: "I would prefer a document about seasons than seasoning if I am on a weather site",
                          description: %q(Some people, when confronted with an information retrieval problem, think "I know, I'll use a stemmer." Now they have two problems.) }
        Document.create(common_params.merge(description: 'jefferson township Memorial new'))
        Document.create(common_params.merge(description: 'jefferson township memorials news'))
        Document.refresh_index!
      end

      it 'ranks those higher' do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "news memorials", size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.results.first['description']).to match(/memorials news/)
      end
    end

    context 'exact match on a document tag' do
      before do
        common_params = { language: 'en', created: DateTime.now, path: 'http://www.agency.gov/page1.html',
                          title: "This mentions stats in the title",
                          description: %q(Some people, when confronted with an information retrieval problem, think "I know, I'll use a stemmer." Now they have two problems.) }
        Document.create(common_params)
        Document.create(common_params.merge(tags: 'stats'))
        Document.create(common_params.merge(tags: 'unimportant stats'))
        Document.refresh_index!
      end

      it 'ranks those higher' do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "Stats", size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(3)
        expect(document_search_results.results.first['tags']).to match_array(['stats'])
      end
    end
  end

  describe "sorting by date" do
    before do
      Document.create(language: 'en', title: 'historical document 1 is historical', description: 'historical description 1 is historical', created: 1.month.ago, path: 'http://www.agency.gov/dir1/page1.html')
      Document.create(language: 'en', title: 'historical document 2 is historical', description: 'historical description 2', created: 1.week.ago, path: 'http://www.agency.gov/dir1/page2.html')
      Document.create(language: 'en', title: 'document 3', description: 'historical description 3', created: DateTime.now, path: 'http://www.agency.gov/dir1/page3.html')
      Document.refresh_index!
    end

    it 'returns results in reverse chronological order based on created timestamp' do
      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "historical", size: 10, offset: 0, sort_by_date: true)
      document_search_results = document_search.search
      expect(document_search_results.results[0]['path']).to eq('http://www.agency.gov/dir1/page3.html')
      expect(document_search_results.results[1]['path']).to eq('http://www.agency.gov/dir1/page2.html')
      expect(document_search_results.results[2]['path']).to eq('http://www.agency.gov/dir1/page1.html')
    end
  end

  describe "filtering on language" do
    before do
      Document.create(language: 'en', title: 'america title 1', description: 'description 1', created: DateTime.now, path: 'http://www.agency.gov/page1.html')
      Document.create(language: 'fr', title: 'america title 1', description: 'description 1', created: DateTime.now, path: 'http://fr.www.agency.gov/page1.html')
      Document.refresh_index!
    end

    it 'returns results from only that language' do
      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :fr, query: "america", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)
      expect(document_search_results.results.first['language']).to eq('fr')
    end
  end

  describe "filtering on tags" do
    before do
      Document.create(language: 'en', title: 'title 1', description: 'description 1', created: DateTime.now, path: 'http://www.agency.gov/page1.html', tags: 'usa')
      Document.create(language: 'en', title: 'title 2', description: 'description 2', created: DateTime.now, path: 'http://www.agency.gov/page2.html', tags: 'york, usa')
      Document.create(language: 'en', title: 'title 3', description: 'description 3', created: DateTime.now, path: 'http://www.agency.gov/page3.html', tags: 'new york, usa')
      Document.create(language: 'en', title: 'title 4', description: 'description 3', created: DateTime.now, path: 'http://www.agency.gov/page4.html', tags: 'random tag')
      Document.refresh_index!
    end

    context 'inclusive filtering' do
      it 'returns results with all of those exact tags' do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "title", size: 10, offset: 0, tags: %w(york))
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
        expect(document_search_results.results.first['tags']).to match_array(%w(york usa))

        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "title", size: 10, offset: 0, tags: %w(york usa))
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
        expect(document_search_results.results.first['tags']).to match_array(%w(york usa))

        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "random tag", size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
        expect(document_search_results.results.first['tags']).to match_array(['random tag'])

        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "random", size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(0)
      end
    end

    context 'exclusive filtering' do
      it 'returns results without those exact tags' do
        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "title", size: 10, offset: 0, ignore_tags: %w(york usa))
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)

        document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "title", size: 10, offset: 0, ignore_tags: %w(york))
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(3)
      end
    end
  end

  describe "filtering on date" do
    before do
      Document.create(language: 'en', title: 'historical document 1', description: 'historical description 1', created: 1.month.ago, path: 'http://www.agency.gov/dir1/page1.html')
      Document.create(language: 'en', title: 'historical document 2', description: 'historical description 2', created: 1.week.ago, path: 'http://www.agency.gov/dir1/page2.html')
      Document.create(language: 'en', title: 'historical document 3', description: 'historical description 3', created: DateTime.now, path: 'http://www.agency.gov/dir1/page3.html')
      Document.refresh_index!
    end

    it 'returns results from only that date range' do
      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "historical", size: 10, offset: 0, min_timestamp: 2.weeks.ago, max_timestamp: 1.day.ago)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)
      expect(document_search_results.results.first['path']).to eq('http://www.agency.gov/dir1/page2.html')
    end
  end

  describe "filtering on site:" do
    before do
      Document.create(language: 'en', title: 'america title 1', description: 'description 1', created: DateTime.now, path: 'http://www.agency.gov/dir1/page1.html')
      Document.create(language: 'en', title: 'america title 1', description: 'description 1', created: DateTime.now, path: 'http://www.agency.gov/dir1/dir2/page1.html')
      Document.create(language: 'en', title: 'america title 1', description: 'description 1', created: DateTime.now, path: 'http://www.other.gov/dir2/dir3/page1.html')
      Document.create(language: 'en', title: 'america title 1', description: 'description 1', created: DateTime.now, path: 'http://agency.gov/page1.html')
      Document.refresh_index!
    end

    it 'returns results from only those sites' do
      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "(site:www.agency.gov/dir1/dir2) america", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)

      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "(site:www.agency.gov/dir1) america", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(2)

      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "(site:agency.gov/) america", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(3)

      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "(site:agency.gov) america", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(3)

      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "(site:agency.gov site:other.gov site:missing.gov/not_there) america", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(4)

      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "(site:agency.gov/dir2 site:other.gov/dir1) america", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to be_zero

      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "(site:www.agency.gov/dir2) america", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to be_zero

      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "(site:www.other.gov)", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)

      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "site:agency.gov", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(3)
    end
  end

  context 'when search term yields no results but a similar spelling does have results' do
    before do
      Document.create(language: 'en', title: '99 problems', description: 'but speling aint one of the 99 problems', created: DateTime.now, path: 'http://en.agency.gov/page1.html', content: "Will I have to pay more if I have employees with health problems")
      Document.create(language: 'es', title: '99 problemas', description: 'pero la ortografía no es uno dello las 99 problemas', created: DateTime.now, path: 'http://es.agency.gov/page1.html', content: '¿Tendré que pagar más si tengo empleados con problemas de la salud?')
      Document.refresh_index!
    end

    it 'should return results for the close spelling for English' do
      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "99 problemz", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)
      expect(document_search_results.suggestion['text']).to eq('99 problems')
      expect(document_search_results.suggestion['highlighted']).to eq("99 problems")
    end

    it 'should return results for the close spelling for Spanish' do
      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :es, query: "99 problemz", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)
      expect(document_search_results.suggestion['text']).to eq('99 problemas')
      expect(document_search_results.suggestion['highlighted']).to eq("99 problemas")
    end
  end

end