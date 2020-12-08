require 'rails_helper'

describe Document do
  let(:valid_params) do
    {
      _id: 'a123',
      language: 'en',
      path: 'http://www.agency.gov/page1.html',
      title: 'My Title',
      created: DateTime.new(2020, 1, 1),
      changed: DateTime.new(2020, 1, 2),
      description: 'My Description',
      content: 'some content',
      promote: true,
      tags: 'this,that',
      click_count: 5
    }
  end

  describe 'attributes' do
    subject(:document) { described_class.new(valid_params) }

    it do
      is_expected.to have_attributes(
        language: 'en',
        path: 'http://www.agency.gov/page1.html',
        title: 'My Title',
        created: DateTime.new(2020, 1, 1),
        changed: DateTime.new(2020, 1, 2),
        description: 'My Description',
        content: 'some content',
        promote: true,
        tags: 'this,that',
        click_count: 5
      )
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_presence_of(:language) }
  end
end
