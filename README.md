# i14y
Search engine for agencies' published content

## Development

- Use `rvm` to install the version of Ruby specified in the `Gemfile`.
- `bundle install`.
- Copy `config/secrets_example.yml` to `config/secrets.yml` and fill in your own secrets. To generate a random long secret, use `rake secret`.

## Tests

`bundle exec rake`

