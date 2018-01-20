#!/usr/bin/env ruby
#
#   check-token-ttl
#
# DESCRIPTION:
#
#   Takes a Vault token as an argument and checks to see whether that
#   token is close to expiring. You can customize the option for when
#   to warn or go critical for the TTL left on a Vault token.
#
#   Some people do not use a load balancer in front of Vault and instead
#   rely on H/A Vaults to redirect to the Vault leader. We support this
#   configuration by allowing you to pass several Vault servers in a
#   comma separated list.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: vault
#
# USAGE:
#   Basic check, expect this token to be valid for at least an hour:
#   check-token-ttl.rb --token $VAULT_TOKEN --servers https://vault.internal --critical 3600
#
#   Check multiple vault servers (useful if you don't use load balancing)
#   check-token-ttl.rb --token $VAULT_TOKEN --servers https://vault.internal,https://vault2.internal
#
#   Check a Vault token from a file on disk
#   check-token-ttl.rb --token $(echo /etc/token) --servers https://vault.internal --critical 3600
#
# LICENSE:
#   (c) AJ Bourg <aj@ajbourg.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'vault'
require 'sensu-plugin/check/cli'

class CheckTokenTTL < Sensu::Plugin::Check::CLI

  option :servers,
         description: 'vault server to connect to, comma separated to try multiple',
         long: '--servers https://vault.company.com',
         required: true,
         proc: Proc.new { |s| s.split(',') }

  option :token,
         description: 'token to check',
         long: '--token 111111-222222-333333-...',
         required: true

  option :duration_warn,
         description: 'warn when the TTL is less than this (in seconds)',
         long: '--warning 3600',
         default: 3600,
         proc: Proc.new { |d| d.to_i }

  option :duration_crit,
         description: 'critical when the TTL is less than this (in seconds)',
         long: '--critical 1800',
         default: 1800,
         proc: Proc.new { |d| d.to_i }

  def run

    token_ttl   = -1
    token_name  = ''
    servers     = config[:servers]
    Vault.token = config[:token]

    # if we get an Exception, let's retry against a different Vault server
    # just in case the first one we hit is broken for some reason
    Vault.with_retries(Exception, attempts: servers.length) do |attempt, e|
      Vault.address = servers[attempt % servers.length]

      token_ttl  = Vault.auth_token.lookup_self.data[:ttl]
      token_name = Vault.auth_token.lookup_self.data[:display_name]
    end

    message = "#{token_name} time to live is #{token_ttl}"

    critical message if token_ttl < config[:duration_crit]
    warning message if token_ttl < config[:duration_warn]
    ok message
  end
end
