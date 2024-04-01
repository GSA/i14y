# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.0.6
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install -y build-essential libcurl4-openssl-dev curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle"

FROM base as build

RUN gem install bundler -v 2.4.7

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local without 'development test' && bundle install

COPY . .

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash rails && \
    chown -R rails:rails /rails

USER 1000:1000

ENV PATH="${PATH}:/home/ruby/.local/bin"

EXPOSE 8081
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "8081"]



