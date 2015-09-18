Docker Deploy
=============

Resources and documentation required to deploy this app using docker.

# Docker #

This deploy uses [phusion/passenger-ruby22](https://hub.docker.com/r/phusion/passenger-ruby22/) as the base docker container.

# Secrets #

Update the secrets.conf.dist with valid environment variables.

# DNS #

Update DNS using route53.

aws route53 change-resource-record-sets --hosted-zone-id Z3TH0HRSNU67AM --change-batch file:///Users/jmatt/dev/lsst/git-lfs/git-lfs-s3-server/docker/r53-record.json 

