i14y
====

[![CircleCI](https://circleci.com/gh/GSA/i14y.svg?style=shield)](https://circleci.com/gh/GSA/i14y)
[![Code Climate](https://codeclimate.com/github/GSA/i14y/badges/gpa.svg)](https://codeclimate.com/github/GSA/i14y)
[![Test Coverage](https://codeclimate.com/github/GSA/i14y/badges/coverage.svg)](https://codeclimate.com/github/GSA/i14y)

Search engine for agencies' published content

## Dependencies/Prerequisistes

You'll need Java 7 to run the included `stream2es` utility that handles copying data from one index version to the next.
Run `java -version` to make sure.

Your Elasticsearch cluster needs the [ICU analysis plugin](https://github.com/elastic/elasticsearch-analysis-icu) and
the [Kuromoji analysis plugin](https://github.com/elastic/elasticsearch-analysis-kuromoji/blob/master/README.md) and
the [Smart Chinese Analysis Plugin](https://github.com/elastic/elasticsearch-analysis-smartcn) installed.

Be sure to restart Elasticsearch after you have installed the plugins.

## Development

- Use `rvm` to install the version of Ruby specified in the `Gemfile`.
- `bundle install`.
- Copy `config/secrets_example.yml` to `config/secrets.yml` and fill in your own secrets. To generate a random long secret, use `rake secret`.
- Run `bundle exec rake i14y:setup` to create the neccessary indexes, index templates, and dynamic field templates.

If you ever want to start from scratch with your indexes/templates, you can clear everything out:
`bundle exec rake i14y:clear_all`

## Tests

`bundle exec rake`

## Deployment

- Set your Airbrake api key in `config/airbrake.yml` in the deployment directory for `/i14y/shared/config`. This will get copied into the current release directory on deployment.
- Update your `config/secrets.yml` file in the deployment directory for `/i14y/shared/config`. This will get copied into the current release directory on deployment.
- Update your `config/newrelic.yml` file in the deployment directory for `/i14y/shared/config`. This will get copied into the current release directory on deployment.
- `bundle exec cap staging deploy` to deploy to a staging environment
- `bundle exec cap production deploy` to deploy to a production environment
