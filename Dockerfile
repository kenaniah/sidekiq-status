# A very simple Dockerfile to allow us to run the test suite from docker compose
FROM ruby:3.4.2
WORKDIR /app
COPY . .
RUN bundle install
RUN bundle exec appraisal install
