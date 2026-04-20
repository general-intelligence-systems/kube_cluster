FROM ruby:3.4-slim

WORKDIR /app

# Install build dependencies and OpenSSL headers
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libyaml-dev \
    libssl-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000
CMD ["bundle", "exec", "falcon", "host"]
