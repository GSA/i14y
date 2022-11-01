# frozen_string_literal: true

require 'rails_helper'

describe DocumentSearchResults do
  describe '#initialize' do
    context 'when no hits are present' do
      let(:result) do
        { 'hits' => { 'total' => 0, 'hits' => [] },
          'aggregations' => {},
          'suggest' => [] }
      end

      context 'when suggestions are present' do
        let(:suggestion_hash) do
          { 'suggestion' =>
                              [{ 'text' => 'blue',
                                 'options' => [{ 'text' => 'bulk',
                                                 'highlighted' => 'bulk' }] }] }
        end

        it 'extracts suggestion' do
          result['suggest'] = suggestion_hash
          expect(described_class.new(result).suggestion).to match(hash_including({ 'text' => 'bulk',
                                                                                   'highlighted' => 'bulk' }))
        end
      end
    end

    context 'when hits are present' do
      let(:result) do
        { 'hits' => { 'total' => 1, 'hits' => [hits] },
          'aggregations' => {},
          'suggest' => [] }
      end
      let(:hits) do
        { '_type' => '_doc',
          '_source' => { 'path' => 'https://search.gov/about/',
                         'created' => '2021-02-03T00:00:00.000-05:00',
                         'language' => 'en',
                         'title_en' => 'About Search.gov | Search.gov' },
          'highlight' => { 'content_en' => ['Some highlighted content'] } }
      end

      it 'extracts hits' do
        expect(described_class.new(result).results).to match(array_including({ 'path' => 'https://search.gov/about/',
                                                                               'created' => '2021-02-03 05:00:00 UTC',
                                                                               'language' => 'en',
                                                                               'title' => 'About Search.gov | Search.gov',
                                                                               'content' => 'Some highlighted content' }))
      end

      context 'when aggregations are present' do
        let(:aggregations_hash) do
          { 'content_type' => { 'doc_count_error_upper_bound' => 0,
                                'sum_other_doc_count' => 0,
                                'buckets' => [{ 'key' => 'article',
                                                'doc_count' => 1 }] },
            'tags' => { 'doc_count_error_upper_bound' => 0,
                        'sum_other_doc_count' => 0,
                        'buckets' => [] } }
        end

        it 'extracts aggregations for non-empty buckets' do
          result['aggregations'] = aggregations_hash
          expect(described_class.new(result).aggregations).to match(array_including({ content_type: [{ value: 'article',
                                                                                                       doc_count: 1 }] }))
        end

        it 'drops aggregations for empty buckets' do
          result['aggregations'] = aggregations_hash
          expect(described_class.new(result).aggregations).not_to include(hash_including(:tags))
        end
      end
    end
  end
end
