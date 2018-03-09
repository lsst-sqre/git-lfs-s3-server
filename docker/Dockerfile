FROM phusion/passenger-ruby24:0.9.29

# based on:
# - https://github.com/phusion/passenger-docker
# - https://engineering.adwerx.com/rails-on-kubernetes-8cd4940eacbe

ARG REPO="https://github.com/lsst-sqre/git-lfs-s3-server"
ARG REF="master"

# Set correct environment variables.
ENV HOME /root

RUN apt-get update -qq && apt-get upgrade -y -o Dpkg::Options::="--force-confold"

# start up nginx
RUN rm -f /etc/service/nginx/down

# remove default nginx config
RUN rm /etc/nginx/sites-enabled/default

# install nginx config
COPY etc/nginx/sites-available/lfs.conf /etc/nginx/sites-available/lfs.conf
RUN ln -s /etc/nginx/sites-available/lfs.conf /etc/nginx/sites-enabled/lfs.conf
COPY etc/nginx/main.d/lfs-secrets.conf /etc/nginx/main.d/lfs-secrets.conf

# install git-lfs-s3-server rails app
WORKDIR /opt/lsst
RUN git clone $REPO -b $REF git-lfs-s3-server
WORKDIR /opt/lsst/git-lfs-s3-server
RUN bundle install

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Use baseimage-docker's init process.
# supports env var pass through to nginx
CMD ["/sbin/my_init"]

EXPOSE 80
