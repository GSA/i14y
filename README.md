i14y
====

[![CircleCI](https://circleci.com/gh/GSA/i14y.svg?style=shield)](https://circleci.com/gh/GSA/i14y)
[![Code Climate](https://codeclimate.com/github/GSA/i14y/badges/gpa.svg)](https://codeclimate.com/github/GSA/i14y)
[![Test Coverage](https://codeclimate.com/github/GSA/i14y/badges/coverage.svg)](https://codeclimate.com/github/GSA/i14y)

Search engine for agencies' published content

## Dependencies/Prerequisites

* Ruby

Use [rvm](https://rvm.io/) to install the version of Ruby specified in `.ruby-version`.

### Docker Services

The required services (MySQL, Elasticsearch, etc.) can be run using Docker. Please refer to [searchgov-services](https://github.com/GSA/search-services) for detailed instructions on centralized configuration for services.

The Elasticsearch services provided by `searchgov-services` is configured to run on the default port, [9200](http://localhost:9200/). To use a different host (with or without port) or set of hosts, set the `ES_HOSTS` environment variable. For example, use following command to run the specs using Elasticsearch running on `localhost:9207`:

    ES_HOSTS=localhost:9207 bin/rspec spec

Verify that Elasticsearch 6.8.x is running on port the expected port (in this example, port 9200):

```
$ curl localhost:9200
{
  "name" : "wp9TsCe",
  "cluster_name" : "docker-cluster",
  "cluster_uuid" : "WGf_peYTTZarT49AtEgc3g",
  "version" : {
    "number" : "6.8.7",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "c63e621",
    "build_date" : "2020-02-26T14:38:01.193138Z",
    "build_snapshot" : false,
    "lucene_version" : "7.7.2",
    "minimum_wire_compatibility_version" : "5.6.0",
    "minimum_index_compatibility_version" : "5.0.0"
  },
  "tagline" : "You Know, for Search"
}
```

## Development

- `bundle install`.
- Copy `config/secrets_example.yml` to `config/secrets.yml` and fill in your own secrets. To generate a random long secret, use `rake secret`.
- Run `bundle exec rake i14y:setup` to create the neccessary indexes, index templates, and dynamic field templates.

If you ever want to start from scratch with your indexes/templates, you can clear everything out:
`bundle exec rake i14y:clear_all`

- Run the Rails server on port 8081 for compatibility with the
  search-gov app:
```
$ rails s -p 8081
```

You should see the default Rails index page on [http://localhost:8081/](http://localhost:8081/).

### Code Quality

We use [Rubocop](https://rubocop.org/) for static code analysis. Settings specific to I14Y are configured via [.rubocop.yml](.rubocop.yml). Settings that can be shared among all Search.gov repos should be configured via the [searchgov_style](https://github.com/GSA/searchgov_style) gem.

## Basic Usage

### Create a collection for storing documents
```
$ curl -u dev:devpwd -XPOST http://localhost:8081/api/v1/collections \
 -H "Content-Type:application/json" -d \
 '{"handle":"test_collection","description":"my test collection","token":"test_collection_token"}'
```

### Create a document within that collection
Use the collection handle and token for authorization:

```
curl http://localhost:8081/api/v1/documents \
  -XPOST \
  -H "Content-Type:application/json" \
  -u test_collection:test_collection_token \
  -d '{"document_id":"1",
      "title":"a doc about rutabagas",
      "path": "http://www.foo.gov/rutabagas.html",
      "created": "2020-05-12T22:35:09Z",
      "description":"Lots of very important info on rutabagas",
      "content":"rutabagas",
      "promote": false,
      "language" : "en",
      "tags" : "tag1, another tag"
      }'
```

### Search for a document within a collection
```
$ curl -u dev:devpwd http://localhost:8081/api/v1/collections/search?handles=test_collection&query=rutabaga
```

## Tests
```
# Fire up Elasticsearch
$ docker-compose up elasticsearch

$ bundle exec rake i14y:setup
$ rake
```
