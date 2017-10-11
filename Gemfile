source 'https://rubygems.org'

ruby '2.3.5'
gem 'rails', '5.1.3'

gem 'rack-cors', '~> 0.4.1'
gem 'grape', '~> 1.0.0'
gem 'thin', '~> 1.7.1'

gem 'jbuilder', '~> 2.7'

gem 'capistrano', '~> 3.9.0'
gem 'capistrano-rails', '~> 1.3'
gem 'capistrano-bundler', '~> 1.2'
gem 'capistrano-passenger', '~> 0.2.0'

gem "elasticsearch-persistence", '0.1.7', require: 'elasticsearch/persistence/model'
gem 'elasticsearch', '1.1.2'
gem 'elasticsearch-model', '~>0.1.0'
gem 'elasticsearch-dsl', '~> 0.1.5'

gem 'newrelic_rpm', '~> 4.2'
gem 'airbrake', '~> 6.1'

gem 'patron', '~> 0.9.1'

group :development, :test do
  gem 'rspec-rails', '~> 3.6.0'
  gem 'pry-byebug', '~> 3.4'
  gem 'pry-rails', '~> 0.3.6'
  gem 'faker', '~> 1.7'
  gem 'awesome_print', '~> 1.8' #To enable in Pry: https://github.com/awesome-print/awesome_print#pry-integration
end

group :test do
  gem 'simplecov', '~> 0.13.0', require: false
  gem "codeclimate-test-reporter", '~> 1.0.8', require: nil
  gem 'fuubar', '~> 2.2'
end
