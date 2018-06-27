require 'rails_helper'

describe 'documents template' do
  INDEX_NAME = Document.index_namespace('template_test')
  TYPE_NAME = 'document'
  NON_CJK_LOCALES = LANGUAGE_ANALYZER_LOCALES - %i(ko ja zh)

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

          %w[com org edu gov mil net].each do |tld|
            context "when encountering a mention of a domain ending in .#{tld}" do
            let(:indexed_field) { "Did you know that amazon.#{tld} sells more than just books?" }
            let(:search_term) { 'amazon' }

            it "allows a document to be searched by the domain mentioned in analyzed_field_#{locale} without its TLD" do
              expect(search_results).to_not be_empty
            end
          end
        end

        context "when encountering a mention of a domain ending in a popular TLD that starts with www." do
          let(:indexed_field) { 'Did you know that www.code.org is good for kids?' }
          let(:search_term) { 'code' }

          it "allows a document to be searched by a domain mentioned in analyzed_field_#{locale} without www and its TLD" do
            expect(search_results).to_not be_empty
          end
        end

        context "when encountering a mention of a domain ending in a popular TLD that starts with http://www." do
          let(:indexed_field) { 'Did you know that http://www.code.org is good for kids?' }
          let(:search_term) { 'code' }

          it "allows a document to be searched by a domain mentioned in analyzed_field_#{locale} without www and its TLD" do
            expect(search_results).to_not be_empty
          end
        end

        context "when encountering a mention of a domain ending in a popular TLD that starts with http:// without www" do
          let(:indexed_field) { 'Did you know that http://www.code.org is good for kids?' }
          let(:search_term) { 'code' }

          it "allows a document to be searched by a domain mentioned in analyzed_field_#{locale} without www and its TLD" do
            expect(search_results).to_not be_empty
          end
        end

        context "when encountering a mention of a domain ending in a popular TLD that starts with https://www." do
          let(:indexed_field) { 'Did you know that http://www.code.org is good for kids?' }
          let(:search_term) { 'code' }

          it "allows a document to be searched by a domain mentioned in analyzed_field_#{locale} without www and its TLD" do
            expect(search_results).to_not be_empty
          end
        end

        context "when encountering a mention of a subdomain with a popular TLD" do
          let(:indexed_field) { 'Did you know that smile.amazon.com sells more than just books?' }
          let(:search_term) { 'smile.amazon' }

          it "allows a document to be searched by a subdomain mentioned in analyzed_field_#{locale} without its TLD" do
            expect(search_results).to_not be_empty
          end
        end

        context "when the target value is mixed case" do
          let(:indexed_field) { 'The new SeArCh.gOV site is the best' }
          let(:search_term) { 'search' }

          it "returns a downcased domain mentioned in analyzed_field_#{locale} without its TLD" do
            expect(search_results).to_not be_empty
          end
        end

        context "when the TLD is not supported" do
          let(:indexed_field) { 'Did you know that amazon.biz sells more than just books?' }
          let(:search_term) { 'amazon' }

          it "fails to return a domain mentioned in analyzed_field_#{locale}" do
            expect(search_results).to be_empty
          end
        end

        context "when the target value is sentence final" do
          let(:indexed_field) { 'Check out the .org URL from amazon. com is their most popular URL but org is better' }
          let(:search_term) { 'amazon' }

          it "does not return a domain mentioned in analyzed_field_#{locale} without its TLD" do
            expect(search_results).to be_empty
          end
        end

        context "when a target value contains a word delimiter" do
          let(:body) { { "analyzed_field_#{locale}" => indexed_field } }
          let(:search_query) { { 'term' => { "analyzed_field_#{locale}.word_delimiter" => search_term } } }

          context "when a target value omits a word delimiter (any non alpha-numeric character) between words" do
            let(:indexed_field) { 'The Wi-Fi can only be fixed after you fill out the form.' }
            let(:search_term) { 'wifi' }

            it "returns a document mentioned in analyzed_field_#{locale} containing the full string" do
              expect(search_results).to_not be_empty
            end
          end

          context "when a target value omits a word delimiter between numbers" do
            let(:indexed_field) { 'Model number 123.04 is the most recent.' }
            let(:search_term) { '12304' }

            it "returns a document mentioned in analyzed_field_#{locale} containing the full string" do
              expect(search_results).to_not be_empty
            end
          end

          context "when a target value omits the word delimiter and contains mixed words and numbers" do
            let(:indexed_field) { 'Form 27B/6 must be filled out before any Central Service technician can do work on the ducts.' }
            let(:search_term) { '27b6' }

            it "returns a document mentioned in analyzed_field_#{locale} containing the full string" do
              expect(search_results).to_not be_empty
            end
          end

          context "when a target value contains only part of a string preceding a word delimiter" do
            let(:indexed_field) { 'Ministry of Public Works form 8570.01-M must also be filled out.' }
            let(:search_term) { '8570' }

            it "returns a document mentioned in analyzed_field_#{locale} containing the full string" do
              expect(search_results).to_not be_empty
            end
          end

          context "when a target value contains concatenated parts of a string preceding multiple word delimiters" do
            let(:indexed_field) { 'Ministry of Public Works form 8570.01-M must also be filled out.' }
            let(:search_term) { '857001' }

            it "returns a document mentioned in analyzed_field_#{locale} containing the full string" do
              expect(search_results).to_not be_empty
            end
          end

          context "when a target value contains the full string containing multiple word delimiters" do
            let(:indexed_field) { 'Ministry of Public Works form 8570.01-M must also be filled out.' }
            let(:search_term) { '857001' }

            it "returns a document mentioned in analyzed_field_#{locale} containing the full string" do
              expect(search_results).to_not be_empty
            end
          end

          context "when the target value is surrounded by word delimiters" do
            let(:indexed_field) { 'Ministry of Public Works form -5uRR0und3d- must also be filled out.' }
            let(:search_term) { '5urr0und3d' }

            it "returns a document mentioned in analyzed_field_#{locale} containing the full string" do
              expect(search_results).to_not be_empty
            end
          end

          context "when the target value is surrounded by word delimiters at the beginning of a string" do
            let(:indexed_field) { 'Ministry of Public Works form .5uRR0und3d.8570 must also be filled out.' }
            let(:search_term) { '5urr0und3d' }

            it "does not return a document mentioned in analyzed_field_#{locale} containing the full string" do
              expect(search_results).to be_empty
            end
          end

          context "when the target value is surrounded by word delimiters string internally" do
            let(:indexed_field) { 'Ministry of Public Works form 8570.5uRR0und3d- must also be filled out.' }
            let(:search_term) { '5urr0und3d' }

            it "does not return a document mentioned in analyzed_field_#{locale} containing the full string" do
              expect(search_results).to be_empty
            end
          end
        end
      end
    end
  end
end