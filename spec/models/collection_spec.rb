# frozen_string_literal: true

require 'rails_helper'

describe Collection do
  subject(:collection) { described_class.new(collection_params) }

  let(:id) { 'agency_blogs' }
  let(:token) { 'secret' }
  let(:collection_params) do
    {
      id: id,
      token: token
    }
  end

  it { is_expected.to be_valid }

  describe 'attributes' do
    it do
      is_expected.to have_attributes(
        id: 'agency_blogs',
        token: 'secret',
        created_at: an_instance_of(Time),
        updated_at: an_instance_of(Time)
      )
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:token) }
  end

  describe '#last_document_sent' do
    subject(:last_document_sent) { collection.last_document_sent }

    context 'when something goes wrong' do
      before do
        allow_any_instance_of(DocumentRepository).
          to receive(:search).and_raise(StandardError)
      end

      it { is_expected.to be nil }
    end
  end
end
