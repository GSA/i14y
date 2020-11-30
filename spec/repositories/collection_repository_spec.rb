# frozen_string_literal: true

require 'rails_helper'

describe CollectionRepository do
  subject(:repository) { described_class.new }

  it_behaves_like 'a repository'

  describe '.klass' do
    subject(:klass) { described_class.klass }

    it { is_expected.to eq(Collection) }
  end
end
