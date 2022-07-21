source 'https://rubygems.org'
gem 'rails', ' ~> 6.1.0'

gem 'rack-cors', '~> 1.0.5'
gem 'grape', '~> 1.3.2'
gem 'jbuilder', '~> 2.7'
# Virtus is no longer supported. Consider replacing with ActiveModel::Attributes
gem 'virtus', '~> 1.0'

gem "elasticsearch-persistence", '~> 6.0'
gem 'elasticsearch', '~> 6.0'
gem 'elasticsearch-dsl', '~> 0.1.9'

gem 'newrelic_rpm', '~> 6.15.0'

gem 'typhoeus', '~> 1.4.0'

gem 'rake', '~> 13.0.0'

group :development, :test do
  gem 'rspec-rails', '~> 3.7'
  gem 'pry-byebug', '~> 3.4'
  gem 'pry-rails', '~> 0.3'
  gem 'faker', '~> 1.7'
  gem 'awesome_print', '~> 1.8' #To enable in Pry: https://github.com/awesome-print/awesome_print#pry-integration
  gem 'listen'
  gem 'puma',  '~> 5.0'
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
