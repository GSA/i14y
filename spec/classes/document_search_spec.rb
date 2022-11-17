# frozen_string_literal: true

require 'rails_helper'

describe DocumentSearch do
  let(:query) { 'common' }
  let(:handles) { %w[agency_blogs] }
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
      content: 'common content'
    }
  end
  let(:document_search) { described_class.new(search_options) }
  let(:document_search_results) { document_search.search }
  let(:documents_index_name) do
    [DocumentRepository.index_namespace('agency_blogs'), 'v1'].join('-')
  end
  # Using a single shard prevents intermittent relevancy issues in tests
  # https://www.elastic.co/guide/en/elasticsearch/guide/current/relevance-is-broken.html
  let(:document_repository) do
    DocumentRepository.new(
      index_name: documents_index_name,
      settings: { index: { number_of_shards: 1 } }
    )
  end

  def create_documents(document_hashes)
    document_hashes.each { |hash| create_document(hash, document_repository) }
  end

  before do
    ES.client.indices.delete(
      index: [DocumentRepository.index_namespace('agency_blogs'), '*'].join('-')
    )
    document_repository.create_index!(include_type_name: true)
    ES.client.indices.put_alias(
      index: documents_index_name,
      name: DocumentRepository.index_namespace('agency_blogs')
    )
  end

  context 'when searching across a single index collection' do
    context 'when matching documents exist' do
      before do
        create_documents([
          {
            language: 'en',
            title: 'title 1 common content',
            description: 'description 1 common content',
            created: DateTime.now,
            path: 'http://www.agency.gov/page1.html'
          }
        ])
      end

      it 'returns results' do
        expect(document_search_results.total).to eq(1)
      end

      it 'returns non-nil aggregations' do
        expect(document_search_results.aggregations).not_to be_nil
      end

      context 'when those documents contain a text type aggregation field' do
        before do
          create_documents([
                             {
                               language: 'en',
                               title: 'title 2 common content',
                               description: 'description 2 common content',
                               created: DateTime.now,
                               tags: 'just, some, tags',
                               path: 'http://www.agency.gov/page1.html'
                             }
                           ])
        end

        let(:tags_arr) { document_search_results.aggregations.find { |a| a[:tags] }[:tags] }

        it 'returns a hash with doc_count and agg_key keys' do
          expect(tags_arr.first.keys).to match(array_including(:agg_key,
                                                               :doc_count))
        end

        it 'returns a hash of doc_count and agg_key values matching the document' do
          expect(tags_arr).to match(array_including({ agg_key: 'just', doc_count: 1 },
                                                    { agg_key: 'some', doc_count: 1 },
                                                    { agg_key: 'tags', doc_count: 1 }))
        end

        it 'does not return an aggregation hash for fields not present in any result doucuments' do
          audience_arr = document_search_results.aggregations.find { |a| a[:audience] }
          expect(audience_arr).to be_nil
        end
      end

      context 'when those documents contain a date type aggregation field' do
        before do
          create_documents([
                             {
                               language: 'en',
                               title: 'title with date agg',
                               description: 'description common content',
                               changed: 6.months.ago.to_s,
                               path: 'http://www.agency.gov/page1.html'
                             }
                           ])
        end

        let(:changed_arr) { document_search_results.aggregations.find { |a| a[:changed] }[:changed] }
        let(:query) { 'date agg' }

        it 'returns a hash with doc_count, agg_key, and date keys' do
          expect(changed_arr.first.keys).to match(array_including(:agg_key,
                                                                  :doc_count,
                                                                  :to,
                                                                  :from,
                                                                  :to_as_string,
                                                                  :from_as_string))
        end

        it 'returns a hash with doc_count, agg_key, and date values matching the document' do
          expect(changed_arr.first).to match(hash_including(agg_key: 'Last Year',
                                                            doc_count: 1,
                                                            to_as_string: DateTime.now.strftime('%-m/%-d/%Y'),
                                                            from_as_string: 1.year.ago.strftime('%-m/%-d/%Y')))
        end

        it 'does not return keys with zero corresponding documents' do
          changed_keys = changed_arr.pluck(:agg_key)
          expect(changed_keys).not_to include('Last Week', 'Last Month')
        end

        it 'does return keys with at least one corresponding document' do
          changed_keys = changed_arr.pluck(:agg_key)
          expect(changed_keys).to include('Last Year')
        end
      end

      context 'when searching without a query' do
        let(:document_search) { described_class.new(search_options.except(:query)) }

        it 'returns results' do
          expect(document_search_results.total).to eq(1)
        end

        it 'returns nil aggregations' do
          expect(document_search_results.aggregations).to be_nil
        end
      end

      context 'when searching without a language' do
        let(:document_search) { described_class.new(search_options.except(:language)) }

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
          let(:document_search) { described_class.new(search_options.merge(include: ['promote'])) }

          it 'returns the specified fields' do
            result = document_search.search.results.first
            expect(result.keys).to include 'promote'
          end
        end
      end
    end

    context 'when no matching documents exist' do
      it 'returns no results ' do
        expect(document_search_results.total).to eq(0)
      end

      it 'returns non-nil aggregations' do
        expect(document_search_results.aggregations).not_to be_nil
      end
    end

    context 'when something terrible happens during the search' do
      let(:query) { 'uh oh' }
      let(:error) { StandardError.new('something went wrong') }

      before { allow(ES).to receive(:client).and_raise(error) }

      it 'returns a no results response' do
        expect(document_search_results.total).to eq(0)
        expect(document_search_results.results).to eq([])
      end

      it 'logs details about the query' do
        expect(Rails.logger).to receive(:error).with(%r{"query":"uh oh"})
        document_search.search
      end

      it 'sends the error to NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error).with(
          error, options: { custom_params: { indices: ['test-i14y-documents-agency_blogs'] } }
        )
        document_search.search
      end
    end
  end

  context 'paginating' do
    before do
      create_documents([
        common_params.merge(title: 'most relevant title common content', description: 'other content'),
        Array.new(10) { |x| common_params.merge(title: "title #{x}", description: "common content #{x}") }
      ].flatten)
    end

    it 'returns "size" results' do
      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: 'common', size: 3, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(11)
      expect(document_search_results.results.size).to eq(3)
    end

    it 'obeys the offset' do
      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: 'common content', size: 10, offset: 1)
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
      create_document(common_params, document_repository)
      es_documents_index_name = [
        DocumentRepository.index_namespace('other_agency_blogs'), 'v1'
      ].join('-')
      other_repository = DocumentRepository.new(index_name: es_documents_index_name)
      other_repository.create_index!(include_type_name: true)
      ES.client.indices.put_alias(
        index: es_documents_index_name,
        name: DocumentRepository.index_namespace('other_agency_blogs')
      )
      create_document(common_params, other_repository)
    end

    it 'returns results from all indexes' do
      document_search = described_class.new(handles: %w[agency_blogs other_agency_blogs], language: :en, query: 'common', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(2)
    end
  end

  describe 'recall' do
    context 'matches on all query terms in URL basename' do
      before do
        create_documents([
          common_params.merge(path: 'http://www.agency.gov/obama-visits-hud.html')
        ])
      end

      it 'matches' do
        document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: 'obama hud', size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
      end
    end

    context 'enough low frequency and high frequency words are found' do
      before do
        create_documents([
          common_params.merge(title: 'low frequency term'),
          common_params.merge(title: 'very rare words'),
          Array.new(80, common_params.merge(title: 'high occurrence tokens',
                                            description: 'these are like stopwords')),
          Array.new(80, common_params.merge(title: 'showing up everywhere',
                                            description: 'these are like stopwords'))
        ].flatten)
      end

      it 'matches 3 out of 4 low freq or missing terms' do
        document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: 'very low frequency term', size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
        document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: 'MISSING low frequency term', size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)
      end

      it 'matches 2 out of 3 high freq terms' do
        document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: 'high occurrence everywhere', size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(80)
      end
    end
  end

  describe 'overall relevancy' do
    context 'exact phrase matches' do
      before do
        create_documents([
          common_params.merge(title: 'jefferson township Petitions and Memorials'),
          common_params.merge(title: 'jefferson Memorial and township Petitions')
        ])
      end

      it 'ranks those higher' do
        document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: 'jefferson Memorial', size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.results.first['title']).to match(/jefferson Memorial/)
      end
    end

    context 'when a search term appears in varying fields' do
      let(:query) { 'rutabaga' }

      before do
        create_documents([
          common_params.merge(title: 'other', description: 'other', content: 'Rutabagas'),
          common_params.merge(title: 'other', description: 'Rutabagas', content: 'other'),
          common_params.merge(title: 'Rutabagas', description: 'other', content: 'other')
        ])
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
          create_documents([
            common_params.merge(path: "http://www.agency.gov/dir1/page1.#{ext}"),
            common_params.merge(path: 'http://www.agency.gov/dir1/page1.html'),
            common_params.merge(path: 'http://www.agency.gov/dir1/page1'),
            common_params.merge(path: 'http://www.agency.gov/dir1/page1.txt')
          ])
        end

        it "docs ending in .#{ext} appear after non-demoted docs" do
          expect(document_search_results.results[3]['path']).to eq("http://www.agency.gov/dir1/page1.#{ext}")
        end
      end
    end

    context 'exact word form matches' do
      before do
        common_params = { language: 'en', created: DateTime.now, path: 'http://www.agency.gov/page1.html',
                          title: 'I would prefer a document about seasons than seasoning if I am on a weather site',
                          description: %q(Some people, when confronted with an information retrieval problem, think "I know, I'll use a stemmer." Now they have two problems.) }
        create_documents([
          common_params.merge(description: 'jefferson township Memorial new'),
          common_params.merge(description: 'jefferson township memorials news')
        ])
      end

      it 'ranks those higher' do
        document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: 'news memorials', size: 10, offset: 0)
        document_search_results = document_search.search
        expect(document_search_results.results.first['description']).to match(/memorials news/)
      end
    end

    context 'exact match on a document tag' do
      let(:document_search) do
        described_class.new(search_options.merge(query: 'Stats', include: ['tags']))
      end
      before do
        common_params = { language: 'en', created: DateTime.now, path: 'http://www.agency.gov/page1.html',
                          title: 'This mentions stats in the title',
                          description: %q(Some people, when confronted with an information retrieval problem, think "I know, I'll use a stemmer." Now they have two problems.) }
        create_documents([
          common_params,
          common_params.merge(tags: 'stats'),
          common_params.merge(tags: 'unimportant stats')
        ])
      end

      it 'ranks those higher' do
        expect(document_search_results.total).to eq(3)
        expect(document_search_results.results.first['tags']).to match_array(['stats'])
      end
    end

    context 'when documents include click counts' do
      before do
        create_documents([
          common_params.merge(path: 'http://agency.gov/popular'),
          common_params.merge(path: 'http://agency.gov/most_popular', click_count: 10),
          common_params.merge(path: 'http://agency.gov/more_popular', click_count: 5)
        ])
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

  describe 'sorting by date' do
    before do
      create_documents([
        common_params.merge(changed: 2.months.ago,
                            path: 'http://www.agency.gov/2months.html'),
        common_params.merge(changed: nil,
                            created: nil,
                            path: 'http://www.agency.gov/nodate.html'),
        common_params.merge(changed: 6.months.ago,
                            path: 'http://www.agency.gov/6months.html'),
        common_params.merge(changed: 1.minute.ago,
                            path: 'http://www.agency.gov/1minute.html'),
        common_params.merge(changed: 3.years.ago,
                            path: 'http://www.agency.gov/3years.html')
      ])
    end

    context 'by default' do
      let(:document_search) do
        described_class.new(search_options.merge(sort_by_date: false))
      end

      it 'returns results in reverse chronological order based on changed timestamp' do
        expect(document_search_results.results.map { |r| r['path'] }).
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
      let(:document_search) do
        described_class.new(search_options.merge(sort_by_date: true))
      end

      it 'returns results in reverse chronological order based on changed timestamp' do
        expect(document_search_results.results.map { |r| r['path'] }).
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

  describe 'filtering on language' do
    before do
      create_documents([
        common_params.merge(language: 'en',
                            title: 'america',
                            path: 'http://www.agency.gov/page1.html'),
        common_params.merge(language: 'fr',
                            title: 'america',
                            path: 'http://fr.agency.gov/page1.html')
      ])
    end

    it 'returns results from only that language' do
      document_search = described_class.new(handles: %w[agency_blogs], language: :fr, query: 'america', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)
      expect(document_search_results.results.first['language']).to eq('fr')
    end
  end

  describe 'filtering on tags' do
    let(:search_options) do
      { handles: handles, language: :en, query: query, size: 10, offset: 0, include: ['tags'] }
    end

    before do
      create_documents([
        common_params.merge(tags: 'usa'),
        common_params.merge(tags: 'york, usa'),
        common_params.merge(tags: 'new york, usa'),
        common_params.merge(tags: 'random tag')
      ])
    end

    context 'inclusive filtering' do
      context 'searching by one tag' do
        let(:document_search) { described_class.new(search_options.merge(query: 'title', tags: %w[york])) }

        it 'returns results matching the exact tag' do
          expect(document_search_results.total).to eq(1)
          expect(document_search_results.results.first['tags']).to match_array(%w[york usa])
        end
      end

      context 'searching by multiple tags' do
        let(:document_search) { described_class.new(search_options.merge(query: 'title', tags: %w[york usa])) }

        it 'returns results matching all of those exact tags' do
          expect(document_search_results.total).to eq(1)
          expect(document_search_results.results.first['tags']).to match_array(%w[york usa])
        end
      end

      context 'when the query matches a tag' do
        let(:document_search) { described_class.new(search_options.merge(query: 'random tag')) }

        it 'returns results matching that tag' do
          expect(document_search_results.total).to eq(1)
          expect(document_search_results.results.first['tags']).to match_array(['random tag'])
        end
      end

      context 'searching by a tag with a partial match' do
        let(:document_search) { described_class.new(search_options.merge(query: 'random')) }

        it 'does not return partially matching results' do
          expect(document_search_results.total).to eq(0)
        end
      end
    end

    context 'exclusive filtering' do
      it 'returns results without those exact tags' do
        document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: 'title', size: 10, offset: 0, ignore_tags: %w[york usa])
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(1)

        document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: 'title', size: 10, offset: 0, ignore_tags: %w[york])
        document_search_results = document_search.search
        expect(document_search_results.total).to eq(3)
      end
    end
  end

  context 'when filtering on dates' do
    let(:document_search) { described_class.new(date_filtered_options) }

    before do
      create_documents([
                         common_params.merge(changed: 1.month.ago,
                                             created: nil,
                                             path: 'http://www.agency.gov/dir1/page1.html'),
                         common_params.merge(changed: 1.week.ago,
                                             created: DateTime.now,
                                             path: 'http://www.agency.gov/dir1/page2.html'),
                         common_params.merge(changed: DateTime.now,
                                             created: 1.week.ago,
                                             path: 'http://www.agency.gov/dir1/page3.html'),
                         common_params.merge(changed: nil,
                                             created: 1.month.ago,
                                             path: 'http://www.agency.gov/dir1/page4.html')
                       ])
    end

    context 'when filtering on changed date range' do
      let(:date_filtered_options) do
        search_options.merge(min_timestamp: 2.weeks.ago,
                             max_timestamp: 1.day.ago)
      end

      it 'returns results from only that date range' do
        expect(document_search_results.total).to eq(1)
        expect(document_search_results.results.first['path']).
          to eq('http://www.agency.gov/dir1/page2.html')
      end
    end

    context 'when filtering on minimum changed date' do
      let(:date_filtered_options) { search_options.merge(min_timestamp: 2.weeks.ago) }

      it 'returns results from only after that minimum date' do
        expect(document_search_results.total).to eq(2)
        expect(document_search_results.results.map { |r| r['path'] }).
          to eq(
            %w[
              http://www.agency.gov/dir1/page2.html
              http://www.agency.gov/dir1/page3.html
            ]
          )
      end
    end

    context 'when filtering on maximum changed date' do
      let(:date_filtered_options) { search_options.merge(max_timestamp: 1.day.ago) }

      it 'returns results from only before that maxium date' do
        expect(document_search_results.total).to eq(2)
        expect(document_search_results.results.map { |r| r['path'] }).
          to eq(
            %w[
              http://www.agency.gov/dir1/page2.html
              http://www.agency.gov/dir1/page1.html
            ]
          )
      end
    end

    context 'when filtering on created date range' do
      let(:date_filtered_options) do
        search_options.merge(min_timestamp_created: 2.weeks.ago,
                             max_timestamp_created: 1.day.ago)
      end

      it 'returns results from only that date range' do
        expect(document_search_results.total).to eq(1)
        expect(document_search_results.results.first['path']).
          to eq('http://www.agency.gov/dir1/page3.html')
      end
    end

    context 'when filtering on minimum created date' do
      let(:date_filtered_options) { search_options.merge(min_timestamp_created: 2.weeks.ago) }

      it 'returns results from only after that minimum date' do
        expect(document_search_results.total).to eq(2)
        expect(document_search_results.results.map { |r| r['path'] }).
          to eq(
            %w[
              http://www.agency.gov/dir1/page2.html
              http://www.agency.gov/dir1/page3.html
            ]
          )
      end
    end

    context 'when filtering on maximum created date' do
      let(:date_filtered_options) { search_options.merge(max_timestamp_created: 1.day.ago) }

      it 'returns results from only before that maxium date' do
        expect(document_search_results.total).to eq(2)
        expect(document_search_results.results.map { |r| r['path'] }).
          to eq(
            %w[
              http://www.agency.gov/dir1/page3.html
              http://www.agency.gov/dir1/page4.html
            ]
          )
      end
    end
  end

  describe 'filtering on site:' do
    let(:common_params) do
      { language: 'en', title: 'america title 1', description: 'description 1' }#created?
    end

    before do
      create_documents([
        common_params.merge(path: 'http://www.agency.gov/dir1/page1.html'),
        common_params.merge(path: 'http://www.agency.gov/dir1/dir2/page1.html'),
        common_params.merge(path: 'http://www.other.gov/dir2/dir3/page1.html'),
        common_params.merge(path: 'http://agency.gov/page1.html')
      ])
    end

    let(:base_search_params) do
      { handles: %w[agency_blogs], language: :en, size: 10, offset: 0 }
    end

    it 'returns results from only those sites' do
      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: '(site:www.agency.gov/dir1/dir2) america', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)

      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: '(site:www.agency.gov/dir1) america', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(2)

      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: '(site:agency.gov/) america', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(3)

      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: '(site:agency.gov) america', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(3)

      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: '(site:agency.gov site:other.gov site:missing.gov/not_there) america', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(4)

      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: '(site:agency.gov/dir2 site:other.gov/dir1) america', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to be_zero

      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: '(site:www.agency.gov/dir2) america', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to be_zero

      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: '(site:www.other.gov)', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)

      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: 'site:agency.gov', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(3)
    end

    context 'when excluding domains' do
      let(:query) { '-site:agency.gov america' }
      let(:document_search_results) { described_class.new(base_search_params.merge(query: query)).search.results }
      let(:document_paths) { document_search_results.map { |result| result['path'] }.join(' ') }

      it 'excludes results from those domains' do
        expect(document_search_results.count).to eq(1)
        expect(document_paths).not_to match(%r{agency.gov})
      end

      context 'when excluding a path' do
        let(:query) { '-site:www.agency.gov/dir1 america' }

        it 'excludes results from that path' do
          expect(document_paths).not_to match(%r{agency.gov/dir1})
          expect(document_search_results.count).to eq(2)
        end

        context 'when the path includes a trailing slash' do
          let(:query) { '-site:www.agency.gov/dir1/ america' }

          it 'excludes results from that path' do
            expect(document_paths).not_to match(%r{agency.gov/dir1})
            expect(document_search_results.count).to eq(2)
          end
        end

        context 'when excluding sub-subdirectories' do
          let(:query) { '-site:www.agency.gov/dir1/dir2 america' }

          it 'excludes results from those paths' do
            expect(document_paths).not_to match(%r{agency.gov/dir1/dir2})
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
      create_documents([
        {
          language: 'en',
          title: '99 problems',
          description: 'but speling aint one of the 99 problems',
          path: 'http://en.agency.gov/page1.html',
          content: 'Will I have to pay more if I have employees with health problems'
        },
        {
          language: 'es',
          title: '99 problemas',
          description: 'pero la ortografía no es uno dello las 99 problemas',
          path: 'http://es.agency.gov/page1.html',
          content: '¿Tendré que pagar más si tengo empleados con problemas de la salud?'
        }
      ])
    end

    it 'should return results for the close spelling for English' do
      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: '99 problemz', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)
      expect(document_search_results.suggestion['text']).to eq('99 problems')
      expect(document_search_results.suggestion['highlighted']).to eq('99 problems')
    end

    it 'should return results for the close spelling for Spanish' do
      document_search = described_class.new(handles: %w[agency_blogs], language: :es, query: '99 problemz', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(1)
      expect(document_search_results.suggestion['text']).to eq('99 problemas')
      expect(document_search_results.suggestion['highlighted']).to eq('99 problemas')
    end

    it 'does not return results from excluded sites' do
      document_search = described_class.new(handles: %w[agency_blogs], language: :en, query: '99 problemz -site:agency.gov', size: 10, offset: 0)
      document_search_results = document_search.search
      expect(document_search_results.total).to eq(0)
    end
  end

  context 'when a search term yields results as well as a suggestion' do
    let(:query) { 'fsands' }

    before do
      create_documents([
        common_params.merge(content: 'FSAND'),
        common_params.merge(content: 'fund'),
        common_params.merge(content: 'fraud')
      ])
    end

    it 'does not return a suggestion' do
      expect(document_search_results.suggestion).to be nil
    end
  end

  describe 'searching by exact phrase' do
    let(:query) { '"amazing spiderman"' }

    before do
      create_documents([
        common_params.merge(content: 'amazing spiderman'),
        common_params.merge(content: 'spiderman is amazing')
      ])
    end

    it 'returns exact matches only' do
      expect(document_search_results.total).to eq 1
      expect(document_search_results.results.first['content']).to eq 'amazing spiderman'
    end

    context 'when a result contains both exact and inexact matches' do
      let(:query) { '"exact phrase"' }

      before do
        create_documents([
          common_params.merge(
            content: 'This phrase match is not exact. This is an exact phrase match'
          )
        ])
      end

      it 'only highlights exact matches' do
        expect(document_search_results.results.first['content']).
          to eq 'match is not exact. This is an exact phrase match'
      end

      context 'when searching by exact and inexact phrases' do
        let(:query) { 'this "exact phrase"' }

        it 'only highlights exact matches' do
          expect(document_search_results.results.first['content']).
            to eq 'This phrase match is not exact. This is an exact phrase match'
        end
      end
    end
  end

  context 'when a document has been promoted' do
    before do
      create_documents([
        common_params.merge(title: 'no', promote: false),
        common_params.merge(title: 'yes', promote: true),
        common_params.merge(title: 'no', promote: false)
      ])
    end

    it 'prioritizes promoted documents' do
      expect(document_search_results.total).to eq 3
      expect(document_search_results.results.first['title']).to eq 'yes'
    end
  end

  context 'stemming' do
    let(:query) { 'renew' }

    before do
      create_documents([
        common_params.merge(content: 'passport renewal'),
        common_params.merge(content: 'renew passport'),
        common_params.merge(content: 'something unrelated')
      ])
    end

    it 'finds similar similar by word stem' do
      expect(document_search_results.total).to eq 2
      expect(document_search_results.results.first['content']).to eq 'renew passport'
    end
  end

  describe 'language support' do
    # Create documents for each supported language
    languages = [
      {
        lang_code: 'en',
        content: 'Select your state or territory from the dropdown menu to find the rules that apply to you.',
        query: 'territory'
      },
      {
        lang_code: 'es',
        content: 'Seleccione su estado o territorio en el menú desplegable y encontrará las normas a seguir.',
        query: 'territorio'
      },
      {
        lang_code: 'hi',
        content: 'आप पर लागू होने वाले नियमों को जानने के लिए ड्रॉपडाउन मेनू से अपना राज्य या क्षेत्र चुनें।',
        query: 'क्षेत्र'
      },
      {
        lang_code: 'bn',
        content: 'আপনার ক্ষেত্রে প্রযোজ্য নিয়মগুলি খুঁজে পেতে ড্রপডাউন মেনু থেকে আপনার রাজ্য বা অঞ্চল নির্বাচন করুন৷',
        query: 'অঞ্চল'
      }
    ]
    languages.each do |lang|
      lang_code, content, query = lang.values_at(:lang_code, :content, :query)
      before do
        create_documents([
                           {
                             language: lang_code,
                             path: "https://vote.gov/#{lang_code}",
                             content: content
                           }
                         ])
      end

      it "gets results for #{lang_code}" do
        document_search_results = described_class.new(search_options.merge(query: query, language: lang_code)).search
        expect(document_search_results.results.first['content']).to match(/#{query}/)
      end
    end
  end
end
