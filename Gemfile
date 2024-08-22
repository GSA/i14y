source 'https://rubygems.org'
gem 'dotenv', groups: [:development, :test]

gem 'rails', '~> 7.1.0'

gem 'rack-cors', '~> 1.0.5'
gem 'grape', '~> 1.7.0'
gem 'jbuilder', '~> 2.7'
# Virtus is no longer supported. Consider replacing with ActiveModel::Attributes
gem 'virtus', '~> 1.0'

gem "elasticsearch-persistence", '~> 6.0'
gem 'elasticsearch', '~> 6.0'
gem 'elasticsearch-dsl', '~> 0.1.9'

gem 'newrelic_rpm', '~> 9.10'

gem 'typhoeus', '~> 1.4.0'

gem 'rake', '~> 13.0.0'

gem "rails_semantic_logger", "~> 4.14"

gem 'puma', '~> 5.6'

gem 'dotenv', '~> 3.1'

group :development, :test do
  gem 'rspec-rails', '~> 3.7'
  gem 'pry-byebug', '~> 3.4'
  gem 'pry-rails', '~> 0.3'
  gem 'awesome_print', '~> 1.8' #To enable in Pry: https://github.com/awesome-print/awesome_print#pry-integration
  gem 'listen'
  gem 'debug'

  # Deployment
  gem 'capistrano', require: false
  gem 'capistrano-rails', require: false
  gem 'capistrano-rbenv', require: false
  gem 'capistrano3-puma', require: false
  gem 'capistrano-newrelic', require: false
end

group :development do
  # Bumping searchgov_style? Be sure to update the Rubocop channel
  # in .codeclimate.yml to match the channel in searchgov_style
  # https://github.com/GSA/searchgov_style/blob/main/.codeclimate.yml
  gem 'searchgov_style', '~> 0.1', require: false
end

group :test do
  gem 'simplecov', '~> 0.13.0', require: false
  gem "codeclimate-test-reporter", '~> 1.0.8', require: nil
  gem 'shoulda', '~> 4.0'
end
