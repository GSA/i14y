i14y
====

[![CircleCI](https://circleci.com/gh/GSA/i14y.svg?style=shield)](https://circleci.com/gh/GSA/i14y)
[![Code Climate](https://codeclimate.com/github/GSA/i14y/badges/gpa.svg)](https://codeclimate.com/github/GSA/i14y)
[![Test Coverage](https://codeclimate.com/github/GSA/i14y/badges/coverage.svg)](https://codeclimate.com/github/GSA/i14y)

Search engine for agencies' published content

## Dependencies/Prerequisites

* Ruby

Use [rvm](https://rvm.io/) to install the version of Ruby specified in `.ruby-version`.

### Docker

Docker can be used to: 1) run just the required services (MySQL, Elasticsearch, etc.) while [running the i14y application in your local machine](https://github.com/GSA/i14y#development), and/or 2) run the entire `i14y` application in a Docker container.  Please refer to [searchgov-services](https://github.com/GSA/search-services) for detailed instructions on centralized configuration for the services.

When running in a Docker container (option 2 above), the `i14y` application is configured to run on port [3200](http://localhost:3200/). Required dependencies - ([Ruby](https://github.com/GSA/i14y#dependenciesprerequisites), and Gems) - are installed using Docker. However, other data or configuration may need to be setup manually, which can be done in the running container using `bash`.

Using bash to perform any operations on i14y application running in Docker container, below command needs to be run in `search-services`.

    $ docker compose run i14y bash

For example, to setup DB in Docker:

    $ docker compose run i14y bash
    $ bin/rails i14y:setup

The Elasticsearch services provided by `searchgov-services` is configured to run on the default port, [9200](http://localhost:9200/). To use a different host (with or without port) or set of hosts, set the `ES_HOSTS` environment variable. For example, use following command to run the specs using Elasticsearch running on `localhost:9207`:

    ES_HOSTS=localhost:9207 bundle exec rspec spec

Verify that Elasticsearch 7.17.x is running on the expected port (port 9200 by default):

```
$ curl localhost:9200
{
  "name" : "002410188f61",
  "cluster_name" : "es7-docker-cluster",
  "cluster_uuid" : "l3cAhBd4Sqa3B4SkpUilPQ",
  "version" : {
    "number" : "7.17.7",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "78dcaaa8cee33438b91eca7f5c7f56a70fec9e80",
    "build_date" : "2022-10-17T15:29:54.167373105Z",
    "build_snapshot" : false,
    "lucene_version" : "8.11.1",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```

## Development

- `bundle install`.
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
# Fire up Elasticsearch in search-services
$ docker-compose up elasticsearch7

$ bundle exec rake i14y:setup
$ rake
```
