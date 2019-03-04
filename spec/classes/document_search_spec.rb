require 'rails_helper'

describe DocumentSearch do
  let(:query) { "common" }
  let(:handles) { %w(agency_blogs) }
  let(:search_options) do
    { handles: handles, language: :en, query: query, size: 10, offset: 0 }
  end
  let(:common_params) do
    {
      language: 'en',
      created: DateTime.now,
      path: 'http://www.agency.gov/page1.html',
      title: 'title',
      description: 'description',
      content: 'common content',
    }
  end
  let(:document_search) { DocumentSearch.new(search_options) }
  let(:document_search_results) { document_search.search }

  before do
    Elasticsearch::Persistence.client.indices.delete(index: [Document.index_namespace('agency_blogs'), '*'].join('-'))
    es_documents_index_name = [Document.index_namespace('agency_blogs'), 'v1'].join('-')
    #Using a single shard prevents intermittent relevancy issues in tests
    #https://www.elastic.co/guide/en/elasticsearch/guide/current/relevance-is-broken.html
    Document.settings(index: { number_of_shards: 1 })
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
        expect(document_search_results.total).to eq(1)
      end

      context 'searching without a query' do
        let(:document_search) { DocumentSearch.new(search_options.except(:query)) }

        it 'returns results' do
          expect(document_search_results.total).to eq(1)
        end
      end

      context 'searching without a language' do
        let(:document_search) { DocumentSearch.new(search_options.except(:language)) }

        it 'defaults to English' do
          expect(document_search_results.results.first['language']).to eq 'en'
        end

        it 'returns results' do
          expect(document_search_results.total).to eq(1)
        end
      end

      describe 'included source fields' do
        # NOTE: 'path', 'created', 'changed', and 'language' all represent the corresponding value
        # in each result's '_source' hash. 'title' and 'description' populated with the highlighted values
        # of those fields during hit extraction; those fields in search results do NOT
        # represent the original value stored in the document's source.
        it 'returns the default fields' do
          result = document_search.search.results.first
          expect(result.keys).to match_array %w[title path created changed language description]
        end

        context 'when specifying included fields' do
          let(:document_search) { DocumentSearch.new(search_options.merge(include: ['promote'])) }

          it 'returns the specified fields' do
            result = document_search.search.results.first
            expect(result.keys).to include 'promote'
          end
        end
      end
    end

    context 'no matching documents exist' do
      it 'returns no results ' do
        expect(document_search_results.total).to eq(0)
      end
    end

    context 'something terrible happens during the search' do
      let(:query) { 'uh oh' }
      let(:error) { StandardError.new('something went wrong') }

      before { allow(Elasticsearch::Persistence.client).to receive(:search).and_raise(error) }

      it 'returns a no results response' do
        expect(document_search_results.total).to eq(0)
        expect(document_search_results.results).to eq([])
      end

      it 'logs details about the query' do
        expect(Rails.logger).to receive(:error).with(%r("query":"uh oh"))
        document_search.search
      end

      it 'sends the error to NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error).with(
          error, options: { custom_params: { indices: ['test-i14y-documents-agency_blogs'] }}
        )
        document_search.search
      end
    end
  end

  context 'paginating' do
    before do
      Document.create(common_params.merge(title: "most relevant title common content", description: "other content"))
      10.times do |x|
        Document.create(common_params.merge(title: "title #{x}", description: "common content #{x}"))
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
        80.times do |_x|
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

    context 'when a search term appears in varying fields' do
      let(:query) { 'rutabaga' }
      before do
         Document.create(common_params.merge( title: 'other', description: 'other', content: 'Rutabagas'))
         Document.create(common_params.merge( title: 'other', description: 'Rutabagas', content: 'other'))
         Document.create(common_params.merge( title: 'Rutabagas', description: 'other', content: 'other'))
         Document.refresh_index!
      end

      it 'prioritizes matches in the title, then description, then content' do
        expect(document_search_results.results.first['title']).to match(/Rutabagas/)
        expect(document_search_results.results[1]['description']).to match(/Rutabagas/)
        expect(document_search_results.results[2]['content']).to match(/Rutabagas/)
      end
    end


    %w[doc docx pdf ppt pptx xls xlsx].each do |ext|
      context 'when the results contain demoted and non-demoted file types' do
        before do
          Document.create(common_params.merge( path: "http://www.agency.gov/dir1/page1.#{ext}"))
          Document.create(common_params.merge( path: 'http://www.agency.gov/dir1/page1.html'))
          Document.create(common_params.merge( path: 'http://www.agency.gov/dir1/page1'))
          Document.create(common_params.merge( path: 'http://www.agency.gov/dir1/page1.txt'))
          Document.refresh_index!
        end

        it "docs ending in .#{ext} appear after non-demoted docs" do
          expect(document_search_results.results[3]['path']).to eq("http://www.agency.gov/dir1/page1.#{ext}")
        end
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
      let(:document_search) do
        DocumentSearch.new(search_options.merge(query: "Stats", include: ['tags']))
      end
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
        expect(document_search_results.total).to eq(3)
        expect(document_search_results.results.first['tags']).to match_array(['stats'])
      end
    end

    context 'when documents include click counts' do
      before do
        Document.create(common_params.merge(path: 'http://agency.gov/popular'))
        Document.create(common_params.merge(path: 'http://agency.gov/most_popular',
                                            click_count: 10))
        Document.create(common_params.merge(path: 'http://agency.gov/more_popular',
                                            click_count: 5))
        Document.refresh_index!
      end

      it 'ranks documents with higher click counts higher' do
        paths = document_search_results.results.map { |doc| doc[:path] }
        expect(paths).to eq (
          %w[http://agency.gov/most_popular
             http://agency.gov/more_popular
             http://agency.gov/popular]
        )
      end
    end
  end

  describe "sorting by date" do
    before do
      Document.create(common_params.merge(created: 2.month.ago, path: 'http://www.agency.gov/2months.html'))
      Document.create(common_params.merge(created: nil, path: 'http://www.agency.gov/nodate.html'))
      Document.create(common_params.merge(created: 6.months.ago, path: 'http://www.agency.gov/6months.html'))
      Document.create(common_params.merge(created: 1.minute.ago, path: 'http://www.agency.gov/1minute.html'))
      Document.create(common_params.merge(created: 3.years.ago, path: 'http://www.agency.gov/3years.html'))
      Document.refresh_index!
    end

    context 'by default' do
      let(:document_search) { DocumentSearch.new(search_options.merge(sort_by_date: false)) }

      it 'returns results in reverse chronological order based on created timestamp' do
        expect(document_search_results.results.map{ |r| r['path'] }).
          to eq (
            %w[
                http://www.agency.gov/nodate.html
                http://www.agency.gov/1minute.html
                http://www.agency.gov/2months.html
                http://www.agency.gov/6months.html
                http://www.agency.gov/3years.html
              ]
          )
      end
    end

    context 'when sorting by date' do
      let(:document_search) { DocumentSearch.new(search_options.merge(sort_by_date: true)) }

      it 'returns results in reverse chronological order based on created timestamp' do
        expect(document_search_results.results.map{ |r| r['path'] }).
          to eq (
            %w[
                http://www.agency.gov/1minute.html
                http://www.agency.gov/2months.html
                http://www.agency.gov/6months.html
                http://www.agency.gov/3years.html
                http://www.agency.gov/nodate.html
              ]
          )
      end
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
    let(:search_options) do
      { handles: handles, language: :en, query: query, size: 10, offset: 0, include: ['tags'] }
    end
    before do
      Document.create(common_params.merge(tags: 'usa'))
      Document.create(common_params.merge(tags: 'york, usa'))
      Document.create(common_params.merge(tags: 'new york, usa'))
      Document.create(common_params.merge(tags: 'random tag'))
      Document.refresh_index!
    end

    context 'inclusive filtering' do
      context 'searching by one tag' do
        let(:document_search) { DocumentSearch.new(search_options.merge(query: "title", tags: %w(york))) }

        it 'returns results matching the exact tag' do
          expect(document_search_results.total).to eq(1)
          expect(document_search_results.results.first['tags']).to match_array(%w(york usa))
        end
      end

      context 'searching by multiple tags' do
        let(:document_search) { DocumentSearch.new(search_options.merge(query: "title", tags: %w(york usa))) }

        it 'returns results matching all of those exact tags' do
          expect(document_search_results.total).to eq(1)
          expect(document_search_results.results.first['tags']).to match_array(%w(york usa))
        end
      end

      context 'when the query matches a tag' do
        let(:document_search) { DocumentSearch.new(search_options.merge(query: "random tag")) }

        it 'returns results matching that tag' do
          expect(document_search_results.total).to eq(1)
          expect(document_search_results.results.first['tags']).to match_array(['random tag'])
        end
      end

      context 'searching by a tag with a partial match' do
        let(:document_search) { DocumentSearch.new(search_options.merge(query: "random")) }

        it 'does not return partially matching results' do
          expect(document_search_results.total).to eq(0)
        end
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
      Document.create(language: 'en', title: 'historical document 4', description: 'historical description 4', created: nil, path: 'http://www.agency.gov/dir1/page4.html')
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

    let(:base_search_params) do
      { handles: %w(agency_blogs), language: :en, size: 10, offset: 0 }
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

    context 'when excluding domains' do
      let(:query) { '-site:agency.gov america' }
      let(:document_search_results) { DocumentSearch.new(base_search_params.merge(query: query )).search.results }
      let(:document_paths) { document_search_results.map{ |result| result['path'] }.join(' ') }

      it 'excludes results from those domains' do
        expect(document_search_results.count).to eq(1)
        expect(document_paths).not_to match(%r(agency.gov))
      end

      context 'when excluding a path' do
        let(:query) { '-site:www.agency.gov/dir1 america' }

        it 'excludes results from that path' do
          expect(document_paths).not_to match(%r(agency.gov/dir1))
          expect(document_search_results.count).to eq(2)
        end

        context 'when the path includes a trailing slash' do
          let(:query) { '-site:www.agency.gov/dir1/ america' }

          it 'excludes results from that path' do
            expect(document_paths).not_to match(%r(agency.gov/dir1))
            expect(document_search_results.count).to eq(2)
          end
        end

        context 'when excluding sub-subdirectories' do
          let(:query) { '-site:www.agency.gov/dir1/dir2 america' }

          it 'excludes results from those paths' do
            expect(document_paths).not_to match(%r(agency.gov/dir1/dir2))
            expect(document_search_results.count).to eq(3)
          end
        end
      end

      context 'when excluding a path that is a partial match' do
        let(:query) { '-site:www.agency.gov/di america' }

        it 'does not exclude those results' do
          expect(document_search_results.count).to eq(4)
        end
      end
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

    it 'does not return results from excluded sites' do
      document_search = DocumentSearch.new(handles: %w(agency_blogs), language: :en, query: "99 problemz -site:agency.gov", size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(0)
    end
  end

  describe "searching by exact phrase" do
    before do
      Document.create(common_params.merge(content: 'amazing spiderman'))
      Document.create(common_params.merge(content: 'spiderman is amazing'))
      Document.refresh_index!
    end
    let(:document_search) { DocumentSearch.new(search_options.merge(query: "\"amazing spiderman\"")) }

    it 'should return exact matches only' do
      expect(document_search_results.total).to eq 1
      expect(document_search_results.results.first['content']).to eq "amazing spiderman"
    end
  end

  context 'when a document has been promoted' do
    before do
      Document.create(common_params.merge(title: 'no', promote: false))
      Document.create(common_params.merge(title: 'yes', promote: true))
      Document.create(common_params.merge(title: 'no', promote: false))
      Document.refresh_index!
    end

    it 'prioritizes promoted documents' do
      expect(document_search_results.total).to eq 3
      expect(document_search_results.results.first['title']).to eq 'yes'
    end
  end

  context 'stemming' do
    let(:query) { 'renew' }

    before do
      Document.create(common_params.merge(content: 'passport renewal'))
      Document.create(common_params.merge(content: 'renew passport'))
      Document.create(common_params.merge(content: 'something unrelated'))
      Document.refresh_index!
    end

    it 'finds similar similar by word stem' do
      expect(document_search_results.total).to eq 2
      expect(document_search_results.results.first['content']).to eq "renew passport"
    end
  end
end
