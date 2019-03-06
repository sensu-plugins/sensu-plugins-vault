#!/usr/bin/env ruby
# frozen_string_literal: false

#
# check-vault-sealed
#
# DESCRIPTION:
#   This plugins checks if vault is up & reachable. It then checks
#   if the vault is unsealed
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
require 'sensu-plugin/check/cli'
require 'vault'

class VaultSealed < Sensu::Plugin::Check::CLI
  option :host,
         description: 'vault host',
         short: '-h HOST',
         long:  '--host HOST',
         default: '127.0.0.1'

  option :port,
         description: 'vault port',
         short: '-p PORT',
         long: '--port PORT',
         default: 8200,
         proc: proc(&:to_i)

  option :protocol,
         description: 'vault http scheme',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'https',
         in: %w[https http]

  option :insecure,
         description: 'Allow insecure connections',
         short: '-k',
         boolean: true,
         default: false

  option :timeout,
         description: 'Timeout on connections to vault',
         short: '-t TIMEOUT',
         long: '--timeout TIMEOUT',
         default: 10

  option :ssl_cert,
         description: 'Path to PEM encoded SSL cert',
         long: '--ssl-cert CERT'

  def run
    # set the vault address
    Vault.address = "#{config[:protocol]}://#{config[:host]}:#{config[:port]}"

    # Allow insecure SSL
    Vault.ssl_verify = false if config[:insecure]

    # Set the connection timeout
    Vault.timeout = config[:timeout]

    # Set SSL pem cert
    Vault.ssl_ca_cert = config[:ssl_cert]

    begin
      if Vault.sys.seal_status.sealed? == true
        critical "Vault is up, but it's sealed"
      else
        ok 'Vault is up and unsealed'
      end
    rescue => ex
      critical ex
    end
  end
end
