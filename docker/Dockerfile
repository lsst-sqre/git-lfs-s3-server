FROM phusion/passenger-ruby22
MAINTAINER J. Matt Peterson <jmatt@lsst.org>

# Install git.
RUN apt-get update
RUN apt-get install -y git

# Setup nginx and passenger
RUN rm -f /etc/service/nginx/down
RUN rm /etc/nginx/sites-enabled/default
ADD git-lfs-s3-server.conf /etc/nginx/sites-enabled/git-lfs-s3-server.conf
ADD secrets-env.conf /etc/nginx/main.d/secrets-env.conf
ADD secrets.conf /etc/nginx/main.d/secrets.conf
RUN git clone https://github.com/lsst-sqre/git-lfs-s3-server.git /home/app/git-lfs-s3-server
RUN cd /home/app/git-lfs-s3-server/;bundle

# Expose the port.
EXPOSE 8080:8080