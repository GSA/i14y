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
      let(:query) { 'this document IS about the theater' }

      it 'strips the stopwords from the query' do
        expect(suggestion_hash[:text]).to eq 'document about theater'
      end
    end
  end
end
