require 'rails_helper'

describe 'documents template' do
  INDEX_NAME = Document.index_namespace('template_test')
  TYPE_NAME = 'document'

  before :all do
    Elasticsearch::Persistence.client.indices.create(index: INDEX_NAME)
  end

  after :all do
    Elasticsearch::Persistence.client.indices.delete(index: INDEX_NAME)
  end

  before do
    Elasticsearch::Persistence.client.index(index: INDEX_NAME, type: TYPE_NAME, body: body)
    Elasticsearch::Persistence.client.indices.refresh(index: INDEX_NAME)
  end

  after do
    Elasticsearch::Persistence.client.delete_by_query(index: INDEX_NAME, q: '*:*', conflicts: 'proceed')
  end

  describe 'domain_minus_ext analyzer' do
    LANGUAGE_ANALYZER_LOCALES.each do |locale|
      context "when analyzing a field with locale #{locale}" do
        let(:body) do
          {
            "analyzed_field_#{locale}" => 'Did you know that amazon.com sells more than just books?'
          }
        end

        it "allows a document to be searched by a domain mentioned in analyzed_field_#{locale} without its TLD" do
          search_results = Elasticsearch::Persistence.client.search({
            index: INDEX_NAME,
            type: TYPE_NAME,
            body: {
              query: {
                'term' => {
                  "analyzed_field_#{locale}.domain_minus_ext" => 'amazon',
                }
              }
            }
          })['hits']['hits']
          expect(search_results).to_not be_empty
        end
      end
    end
  end
end
