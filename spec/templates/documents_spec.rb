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
    subject(:search_results) do
      Elasticsearch::Persistence.client.search({
        index: INDEX_NAME,
        type: TYPE_NAME,
        body: {
          query: search_query
        }
      })['hits']['hits']
    end

    LANGUAGE_ANALYZER_LOCALES.each do |locale|
      let(:body) { { "analyzed_field_#{locale}" => indexed_field } }
      let(:search_query) { { 'term' => { "analyzed_field_#{locale}.domain_minus_ext" => search_term } } }

      context "when analyzing a field with locale #{locale}" do
        context "when encountering a mention of a domain ending in the .com TLD" do
          let(:indexed_field) { 'Did you know that amazon.com sells more than just books?' }
          let(:search_term) { 'amazon' }

          it "allows a document to be searched by a domain mentioned in analyzed_field_#{locale} without its TLD" do
            expect(search_results).to_not be_empty
          end
        end

        context "when encountering a mention of a subdomain with a .com TLD" do
          let(:indexed_field) { 'Did you know that smile.amazon.com sells more than just books?' }
          let(:search_term) { 'smile.amazon' }

          it "allows a document to be searched by a subdomain mentioned in analyzed_field_#{locale} without its TLD" do
            expect(search_results).to_not be_empty
          end
        end

        context "when the target value is mixed case" do
          let(:indexed_field) { 'Did you know that AmAzOn.com sells more than just books?' }
          let(:search_term) { 'amazon' }

          it "returns a downcased domain mentioned in analyzed_field_#{locale} without its TLD" do
            expect(search_results).to_not be_empty
          end
        end

        context "when the TLD is not .com" do
          let(:indexed_field) { 'Did you know that amazon.org sells more than just books?' }
          let(:search_term) { 'amazon' }

          it "fails to return a domain mentioned in analyzed_field_#{locale}" do
            expect(search_results).to be_empty
          end
        end
      end
    end
  end
end