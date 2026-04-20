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

COPY config.ru ./

EXPOSE 3000
CMD ["bundle", "exec", "falcon", "serve", "--bind", "http://0.0.0.0:3000"]
