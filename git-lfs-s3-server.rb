#!/usr/bin/env ruby
# frozen_string_literal: true

require 'logger'
require 'git-lfs-s3'
require 'multi_json'
require 'octokit'
require 'redis'
require 'scrypt'

####
# Configure the server.
####

# Configure lsst-git-lfs-s3 gem.
GitLfsS3::Application.set :aws_region, ENV['AWS_REGION']
GitLfsS3::Application.set :aws_access_key_id, ENV['AWS_ACCESS_KEY_ID']
GitLfsS3::Application.set :aws_secret_access_key, ENV['AWS_SECRET_ACCESS_KEY']
GitLfsS3::Application.set :s3_bucket, ENV['S3_BUCKET']
GitLfsS3::Application.set :server_url, ENV['LFS_SERVER_URL']
GitLfsS3::Application.set :public_server, (ENV['LFS_PUBLIC_SERVER'] == 'true')
GitLfsS3::Application.set :ceph_s3, (ENV['LFS_CEPH_S3'] == 'true')
GitLfsS3::Application.set :endpoint, ENV['LFS_CEPH_ENDPOINT']
GitLfsS3::Application.set :logger, Logger.new(STDOUT)

# GitHub Organization used to verify membership.
GITHUB_ORG = ENV['LFS_GITHUB_ORG'] || 'lsst'

# Configure and connect redis.
args = {}

{
  'LFS_REDIS_HOST' => :host,
  'LFS_REDIS_PORT' => :port,
}.each do |k, v|
  ENV.key?(k) && args[v] = ENV[k]
end

@redis = Redis.new(args)
begin
  @redis.ping
rescue Redis::BaseConnectionError => e
  GitLfsS3::Application.settings.logger.warn e.message
end

# Seconds to cache valid authentication.
CACHE_EXPIRE = 900

# Configure scrypt for caching.
SCrypt::Engine.calibrate

# Configure aws-sdk for Ceph S3.
if GitLfsS3::Application.settings.ceph_s3
  unless GitLfsS3::Application.settings.public_server
    raise 'Ceph S3 only supports public_server mode.'
  end
  unless GitLfsS3::Application.settings.endpoint
    raise 'Ceph S3 requires an endpoint.'
  end

  Aws.config.update(
    endpoint:          ENV['LFS_CEPH_ENDPOINT'],
    access_key_id:     ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    force_path_style:  true,
    region:            'us-east-1',
    # ssl_ca_bundle: '/usr/local/etc/openssl/cert.pem' # Required for brew
    # install on a mac.
  )
end

####
# Authenticate using GitHub. Cache using redis.
####

def org_member?(client)
  client.user # Authenticate User.
  client.org_member?(GITHUB_ORG, client.user.login)
rescue Octokit::OneTimePasswordRequired
  GitLfsS3::Application.settings.logger.warn <<~WARN
    Octokit::OneTimePasswordRequired exception raised for
    username #{client.user.login}.
    Please use a personal access token.
  WARN
  false
rescue Octokit::Unauthorized
  false
end

def get_password_hash(username)
  # Use the request username to avoid using the github API unnecessarily.
  return unless @redis.connected?

  cached_hash = @redis.get(username)
  SCrypt::Password.new(cached_hash) if cached_hash
end

def verify_user_and_permissions?(client, username, password)
  cached_password = get_password_hash(username)
  return cached_password == password if cached_password

  if org_member?(client)
    hash = SCrypt::Password.create(
      password,
      salt: SCrypt::Engine.generate_salt
    )
    @redis.set(client.user.login, hash, ex: CACHE_EXPIRE)
    return true
  end
rescue Redis::BaseConnectionError => e
  GitLfsS3::Application.settings.logger.warn e.message
end

GitLfsS3::Application.on_authenticate do |username, password, is_safe|
  return true if is_safe

  client = Octokit::Client.new(login:    username,
                               password: password)
  verify_user_and_permissions?(client, username, password)
end
