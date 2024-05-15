# frozen_string_literal: true

require 'rails_helper'

describe 'ActiveSupport::ParameterFilter' do
  let(:config) { I14y::Application.config }
  let(:parameter_filter) { ActiveSupport::ParameterFilter.new(config.filter_parameters) }

  it 'filters query from logs' do
    filter_contains_query = config.filter_parameters.any? do |param|
      param.is_a?(Regexp) ? param.to_s.include?('(?i:query)') : param == :query
    end
    expect(filter_contains_query).to be true
  end
end
