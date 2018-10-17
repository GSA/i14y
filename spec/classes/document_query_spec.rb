require 'rails_helper'

describe DocumentQuery do
  let(:query) { 'test' }
  let(:options) do
    { query: query }
  end
  let(:document_query) { DocumentQuery.new(options) }
  let(:body) { document_query.body.to_hash }

  describe '#body' do
    context 'when a query includes stopwords' do
      let(:suggestion_hash) { body[:suggest][:suggestion] }
      let(:query) { 'this is a test' }

      it 'uses "suggest_mode: always" for the suggestion generator' do
        expect(suggestion_hash[:phrase]).to include(
          direct_generator: [{ field: 'bigrams', suggest_mode: 'always' }]
        )
      end
    end
  end
end
