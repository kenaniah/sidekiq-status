# A very simple Dockerfile to allow us to run the test suite from docker compose
FROM ruby:3.3.5
WORKDIR /app
COPY . .
RUN bundle install
