#!/bin/bash

echo "Waiting for Elasticsearch..."
echo $ELASTICHOST
while ! nc -z $ELASTICHOST $ELASTICPORT; do
  sleep 1
  echo "Elasticsearch Not Found"
done
echo "Elasticsearch started"

bundle exec rake i14y:clear_all

bundle exec rake i14y:setup

exec "$@"