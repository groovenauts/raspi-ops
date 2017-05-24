FROM ruby:2.4
MAINTAINER magellan@groovenauts.jp

WORKDIR /usr/src/app

ADD Gemfile /usr/src/app/Gemfile
ADD Gemfile.lock /usr/src/app/Gemfile.lock
ARG bundle_install_env="--without test development"
RUN bundle install --system ${bundle_install_env} && rm /usr/local/lib/ruby/gems/2.4.0/cache/*.gem && rm /usr/local/bundle/cache/*.gem

ADD . /usr/src/app

CMD ["bundle", "exec", "ruby", "predict.rb"]
