set :passenger_restart_with_sudo, true
server 'dbmaster', user: 'search', roles: %w{web app}
