#!/usr/bin/env ruby
# require 'rubygems'
require 'logger'
require 'git-lfs-s3'
require 'octokit'
require 'redis'
require 'scrypt'

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
GITHUB_ORG = 'lsst'

# Configure redis.
@redis = Redis.new
# Seconds to cache valid authentication.
CACHE_EXPIRE = 900

# Configure scrypt for caching.
SCrypt::Engine.calibrate

# Configure aws-sdk for Ceph S3.
if GitLfsS3::Application.settings.ceph_s3
  if not GitLfsS3::Application.settings.public_server
    raise 'Ceph S3 only supports public_server mode.'
  end
  if not GitLfsS3::Application.settings.endpoint
    raise 'Ceph S3 requires an endpoint.'
  end
  Aws.config.update(
    endpoint: ENV['LFS_CEPH_ENDPOINT'],
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    force_path_style: true,
    region: 'us-east-1',
    # ssl_ca_bundle: '/usr/local/etc/openssl/cert.pem' # Required for brew install on a mac.
)
end

def org_member?(client)
  begin
    client.user # Authenticate User.
    if client.org_member?(GITHUB_ORG, client.user.login)
      return true
    else
      return false
    end
  rescue Octokit::OneTimePasswordRequired => e
    GitLfsS3::Application.settings.logger.warn\
      'Octokit::OneTimePasswordRequired exception raised for username #{username}.'
    return false
  rescue Octokit::Unauthorized
    return false
  end
end

def verify_user_and_permissions?(client, username, password)
  result = false
  begin
    # Use the request username to avoid using the github API.
    if @redis.connected?
      cached_hash = @redis.get(username)
    else
      cached_hash = nil
    end
    if cached_hash
      cached_password = SCrypt::Password.new(cached_hash)
      result = cached_password == password
    else
      if org_member?(client)
        result = true
        hash = SCrypt::Password.create(
          password,
          salt: SCrypt::Engine.generate_salt)
        @redis.set(client.user.login, hash, ex: CACHE_EXPIRE)
      else
        result = false
      end
    end
  rescue Redis::BaseConnectionError => e
    GitLfsS3::Application.settings.logger.warn\
      e.message
  end
  return result
end

GitLfsS3::Application.on_authenticate do |username, password, is_safe|
  if is_safe
    true
  else
    client = Octokit::Client.new(:login => username,
                                 :password => password)
    verify_user_and_permissions?(client, username, password)
  end
end
