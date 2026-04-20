FROM ruby:3.4-slim

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libyaml-dev \
    libssl-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile ./
RUN bundle install

COPY config.ru falcon.rb ./

EXPOSE 3000
CMD ["bundle", "exec", "falcon", "host"]
