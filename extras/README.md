Deploy
======

Resources and documentation required to deploy this app.

# Nginx and Passenger #

This deploy uses nginx and passenger.

# Nginx #

Create the `main.d` directory in the `nginx` directory.

```bash
mkdir -p /etc/nginx/main.d
```

Add the `main.d` directory to the `nginx.conf` before the http block.

```nginx
include /etc/nginx/main.d/*.conf;
```

Create a `secrets.conf` using the `secrets.conf.dist` template and link it
in the `nginx/main.d`.

```bash
ln -s /path/to/git-lfs-s3-server/extra/secrets.conf /etc/nginx/main.d/
```

Link the git-lfs-s3-server.conf file in `nginx/conf.d` or `nginx/sites-available` and `nginx/sites-enabled` directories.

```bash
ln -s /path/to/git-lfs-s3-server/extra/secrets.conf /etc/nginx/conf.d/
```

or

```bash
ln -s /path/to/git-lfs-s3-server/extra/git-lfs-s3-server.conf /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/git-lfs-s3-server.conf /etc/nginx/sites-enabled/
```

# RVM and Passenger #

Install [rvm|https://rvm.io/].

```bash
rvm install ruby-2.2.3
rvm use ruby-2.2.3
cd /path/to/git-lfs-s3-server/
bundle
ln -s /etc/nginx/conf.d/ /path/to/git-lfs-s3-server/extra/passenger.conf
```

Note: that passenger.conf is configured to use rvm ruby-2.2.3.

# Restart the web server #

```bash
service nginx restart
```

# DNS #

Update DNS using route53.

aws route53 change-resource-record-sets --hosted-zone-id Z3TH0HRSNU67AM --change-batch file:///path/to/git-lfs-s3-server/extra/r53-record.json 
