FROM ruby:2.7.5-alpine
RUN apk update --no-cache
RUN apk upgrade --no-cache
RUN apk add --no-cache tzdata
RUN cp /usr/share/zoneinfo/US/Central /etc/localtime
RUN echo "US/Central" > /etc/timezone

RUN apk add --no-cache git mariadb-dev mariadb-client qt5-qtbase build-base  \
  && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock /app/
WORKDIR /app
RUN bundler install
RUN bundle install
COPY . /app/
