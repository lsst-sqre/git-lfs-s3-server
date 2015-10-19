#!/usr/bin/env ruby
require 'rubygems'
require 'logger'
require 'git-lfs-s3'
require 'octokit'

GitLfsS3::Application.set :aws_region, ENV['AWS_REGION']
GitLfsS3::Application.set :aws_access_key_id, ENV['AWS_ACCESS_KEY_ID']
GitLfsS3::Application.set :aws_secret_access_key, ENV['AWS_SECRET_ACCESS_KEY']
GitLfsS3::Application.set :s3_bucket, ENV['S3_BUCKET']
GitLfsS3::Application.set :server_url, ENV['LFS_SERVER_URL']
GitLfsS3::Application.set :public_server, (ENV['LFS_PUBLIC_SERVER'] == 'true')
GitLfsS3::Application.set :ceph_s3, (ENV['LFS_CEPH_S3'] == 'true')
GitLfsS3::Application.set :endpoint, ENV['LFS_CEPH_ENDPOINT']
GitLfsS3::Application.set :logger, Logger.new(STDOUT)

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

def verify_user_and_permissions(username, password)
  begin
    client = Octokit::Client.new(:login => username,
                                 :password => password)
    client.user
    if client.org_member?('lsst', client.user.login)
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

GitLfsS3::Application.on_authenticate do |username, password, is_safe|
  if is_safe
    true
  else
    verify_user_and_permissions(username, password)
  end
end
