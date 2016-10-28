require 'rails_helper'
require 'rake'

describe 'create fake test documents' do

  describe 'fake:documents' do
    let(:task_name) { 'fake:documents' }

    before(:all) do
      Rake.application = Rake::Application.new
      Rake.application.rake_require('tasks/fake')
      Rake::Task.define_task(:environment)
    end

    it 'generates the required number of documents' do
      expect(Document).to receive(:create).exactly(3).times
      Rake::Task['fake:documents'].invoke('my_drawer','3')
    end
  end
end
