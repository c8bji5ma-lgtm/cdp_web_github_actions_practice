# syntax=docker/dockerfile:1
ARG RUBY_VERSION=4.0.6
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libpq5 && \
    rm -rf /var/lib/apt/lists/*
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

FROM base AS build
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libpq-dev && \
    rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf /usr/local/bundle/ruby/*/cache
COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base
RUN groupadd --system --gid 1000 rails && \
    useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash rails
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails
USER 1000:1000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
