# config valid for current version and patch releases of Capistrano
lock '~> 3.19.1'

set :application,     'i14y'
set :branch,          ENV.fetch('SEARCH_ENV', 'staging')
set :deploy_to,       ENV.fetch('DEPLOYMENT_PATH')
set :format,          :pretty
set :puma_access_log, "#{release_path}/log/puma.access.log"
set :puma_bind,       'tcp://0.0.0.0:8081'
set :puma_error_log,  "#{release_path}/log/puma.error.log"
set :rails_env,       'production'
set :rbenv_type,      :user
set :repo_url,        'https://github.com/GSA/i14y.git'
set :user,            ENV.fetch('SERVER_DEPLOYMENT_USER', 'search')

append :linked_files, '.env'
append :linked_dirs,  'log', 'tmp'

API_SERVER_ADDRESSES = JSON.parse(ENV.fetch('API_SERVER_ADDRESSES', '[]'))

role :app,  API_SERVER_ADDRESSES, user: ENV['SERVER_DEPLOYMENT_USER']
role :db,   API_SERVER_ADDRESSES, user: ENV['SERVER_DEPLOYMENT_USER']
role :web,  API_SERVER_ADDRESSES, user: ENV['SERVER_DEPLOYMENT_USER']

set :ssh_options, {
  auth_methods:  %w(publickey),
  forward_agent: false,
  keys:          [ENV['SSH_KEY_PATH']],
  user:          ENV['SERVER_DEPLOYMENT_USER']
}

set :linked_files, %w{
  .env
  config/master.key
}

