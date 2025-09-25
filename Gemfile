# frozen_string_literal: true
source 'https://rubygems.org'

gem 'dotenv',                    '~> 3.1'
gem 'elasticsearch',             '~> 6.0'
gem 'elasticsearch-dsl',         '~> 0.1.9'
gem 'elasticsearch-persistence', '~> 6.0'
gem 'grape',                     '~> 1.7.0'
gem 'jbuilder',                  '~> 2.7'
gem 'newrelic_rpm',              '~> 9.10'
gem 'puma',                      '~> 5.6'
gem 'rack',                      '~> 2.2.18'
gem 'rack-cors',                 '~> 1.0.5'
gem 'rails',                     '~> 7.1.0'
gem 'rails_semantic_logger',     '~> 4.14'
gem 'rake',                      '~> 13.0.0'
gem 'typhoeus',                  '~> 1.4.0'
gem 'virtus',                    '~> 1.0' # Virtus is no longer supported. Consider replacing with ActiveModel::Attributes

group :development, :test do
  gem 'awesome_print',       '~> 1.8' #To enable in Pry: https://github.com/awesome-print/awesome_print#pry-integration
  gem 'capistrano',          require: false
  gem 'capistrano3-puma',    require: false
  gem 'capistrano-newrelic', require: false
  gem 'capistrano-rails',    require: false
  gem 'capistrano-rbenv',    require: false
  gem 'debug'
  gem 'listen'
  gem 'pry-byebug',          '~> 3.4'
  gem 'pry-rails',           '~> 0.3'
  gem 'rspec-rails',         '~> 3.7'
  gem 'rubocop',              require: false
  gem 'rubocop-performance',  require: false
  gem 'rubocop-rails',        require: false
  gem 'rubocop-rake',         require: false
  gem 'rubocop-rspec',        require: false
end

group :test do
  gem 'codeclimate-test-reporter', '~> 1.0.8', require: nil
  gem 'shoulda', '~> 4.0'
  gem 'simplecov', '~> 0.13.0', require: false
end
