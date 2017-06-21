SimpleCov.start 'rails' do
  minimum_coverage 100
  add_filter '/templates/'
  add_filter '/lib/templatable.rb'
  add_filter '/app/models/application_record.rb'
end
