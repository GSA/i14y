require 'rails_helper'

describe Collection do
  subject(:collection) { described_class.new(collection_params) }

  let(:id) { 'agency_blogs' }
  let(:token) { 'secret' }
  let(:collection_params) do
    {
      _id: id,
      token: token
    }
  end

  it { is_expected.to be_valid }

  describe 'attributes' do
    it do
      is_expected.to have_attributes(
        token: 'secret',
        id: 'agency_blogs'
      )
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:token) }
  end
end
