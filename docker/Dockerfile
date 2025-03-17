FROM ruby:3.1.3-slim
RUN mkdir /na
WORKDIR /na
RUN gem install bundler:2.2
COPY ./docker/sources.list /etc/apt/sources.list
RUN apt-get update -y --allow-insecure-repositories || true
RUN apt-get install -y less vim
COPY ./docker/inputrc /root/.inputrc
COPY ./docker/bash_profile /root/.bash_profile
CMD ["/na/scripts/runtests.sh"]
