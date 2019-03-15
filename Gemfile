source 'https://rubygems.org'
gem 'rails', '5.1.6.2'

gem 'rack-cors', '~> 0.4.1'
gem 'grape', '~> 1.1.0'
gem 'thin', '~> 1.7.1'

gem 'jbuilder', '~> 2.7'

gem 'capistrano', '~> 3.9.0'
gem 'capistrano-rails', '~> 1.3'
gem 'capistrano-bundler', '~> 1.2'
gem 'capistrano-passenger', '~> 0.2.0'

gem "elasticsearch-persistence", '5.0.2', require: 'elasticsearch/persistence/model'
gem 'elasticsearch', '5.0.4'
gem 'elasticsearch-model', '~> 5.0.2'
gem 'elasticsearch-dsl', '~> 0.1.5'

gem 'newrelic_rpm', '~> 4.2'
gem 'airbrake', '~> 7.1'

gem 'patron', '~> 0.10.0'

group :development, :test do
  gem 'rspec-rails', '~> 3.7'
  gem 'pry-byebug', '~> 3.4'
  gem 'pry-rails', '~> 0.3'
  gem 'faker', '~> 1.7'
  gem 'awesome_print', '~> 1.8' #To enable in Pry: https://github.com/awesome-print/awesome_print#pry-integration
  # Updating rubocop? Update & run mry to ensure rubocop.yml is updated:
  # https://github.com/pocke/mry#usage (include the target version to add new cops)
  # Also bump the rubocop channel in .codeclimate.yml:
  # https://docs.codeclimate.com/v1.0/docs/rubocop#section-using-rubocop-s-newer-versions
  gem 'rubocop', '0.52.1'
  gem 'mry', '~> 0.52.0'
end

group :test do
  gem 'simplecov', '~> 0.13.0', require: false
  gem "codeclimate-test-reporter", '~> 1.0.8', require: nil
  gem 'fuubar', '~> 2.2'
end
