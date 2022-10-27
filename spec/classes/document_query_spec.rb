# frozen_string_literal: true

require 'rails_helper'

describe DocumentQuery do
  let(:query) { 'test' }
  let(:options) do
    { query: query }
  end
  let(:document_query) { described_class.new(options) }
  let(:body) { document_query.body.to_hash }

  describe '#body' do
    context 'when a query includes stopwords' do
      let(:suggestion_hash) { body[:suggest][:suggestion] }
      let(:query) { 'this document IS about the theater' }

      it 'strips the stopwords from the query' do
        expect(suggestion_hash[:text]).to eq 'document about theater'
      end
    end

    it 'contains aggregations' do
      expect(body[:aggregations]).to match(
        hash_including(:audience,
                       :content_type,
                       :mime_type,
                       :searchgov_custom1,
                       :searchgov_custom2,
                       :searchgov_custom3,
                       :tags)
      )
    end

    context 'when the query is blank' do
      let(:query) { '' }

      it 'does not contain aggregations' do
        expect(body[:aggregations]).to be_nil
      end
    end
  end
end
