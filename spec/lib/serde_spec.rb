require 'rails_helper'

describe Serde do
  context '.uri_params_hash' do
    subject(:result) { Serde.uri_params_hash(path) }
    let(:path) { 'https://www.agency.gov/directory/page1.html' }

    it 'computes basename' do
      expect(result[:basename]).to eq('page1')
    end

    it 'computes filename extension' do
      expect(result[:extension]).to eq('html')
    end

    context 'when the extension has uppercase characters' do
      let(:path) { 'https://www.agency.gov/directory/PAGE1.PDF' }

      it 'computes a downcased version of filename extension' do
        expect(result[:extension]).to eq('pdf')
      end
    end

    context 'when there is no filename extension' do
      let(:path) { 'https://www.agency.gov/directory/page1' }

      it 'computes an empty filename extension' do
        expect(result[:extension]).to eq('')
      end
    end

    it 'computes url_path' do
      expect(result[:url_path]).to eq('/directory/page1.html')
    end

    it 'computes domain_name' do
      expect(result[:domain_name]).to eq('www.agency.gov')
    end
  end
end
