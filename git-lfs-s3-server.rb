#!/usr/bin/env ruby
# require 'rubygems'
require 'after_do'
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
@redis = Redis.new
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

####
# Authenticate using GitHub. Cache using redis.
####

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
      'Octokit::OneTimePasswordRequired exception raised for username #{username}. '\
      'Please use a personal access token.'
    return false
  rescue Octokit::Unauthorized
    return false
  end
end

def get_password_hash(username)
  # Use the request username to avoid using the github API unnecessarily.
  if @redis.connected?
    cached_hash = @redis.get(username)
    if cached_hash
      SCrypt::Password.new(cached_hash)
    end
  end
end

def verify_user_and_permissions?(client, username, password)
  begin
    cached_password = get_password_hash(username)
    if cached_password
      return cached_password == password
    else
      if org_member?(client)
        hash = SCrypt::Password.create(
          password,
          salt: SCrypt::Engine.generate_salt)
        @redis.set(client.user.login, hash, ex: CACHE_EXPIRE)
        return true
      end
    end
  rescue Redis::BaseConnectionError => e
    GitLfsS3::Application.settings.logger.warn\
      e.message
  end
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

####
# Notify Backup Service
####

def authorized?(env, app)
  auth = Rack::Auth::Basic::Request.new(env)
  GitLfsS3::Application.settings.logger.warn env
  GitLfsS3::Application.settings.logger.warn auth
  auth.provided? && auth.basic? && auth.credentials && app.class.auth_callback.call(
    auth.credentials[0], auth.credentials[1], false
  )
end

GitLfsS3::Application.extend AfterDo
GitLfsS3::Application.after :call do |env, app|
  req = Rack::Request.new(env)
  if req.post? and req.path == '/verify'\
    and req.content_type.include?('application/vnd.git-lfs+json')\
    and authorized? env, app
      GitLfsS3::Application.settings.logger.debug req.body.tap { |b| b.rewind }.read
      data = MultiJson.load(req.body.tap { |b| b.rewind }.read)
      oid = data['oid']
      oid_s3_name = 'data/' + oid
      if @redis.connected?
        if not @redis.get('backup=>' + oid_s3_name)
          @redis.publish 'backup', oid_s3_name
          GitLfsS3::Application.settings.logger.debug 'Publish message to backup S3 object #{oid_s3_name}.'
        end
      else
        GitLfsS3::Application.settings.logger.warn 'Unable to backup oid = #{oid}'
      end
  end
end
