require "resolv"
require "ipaddr"

module Security
  class SsrfValidator
    BLOCKED_RANGES = [
      IPAddr.new("0.0.0.0/8"),
      IPAddr.new("10.0.0.0/8"),
      IPAddr.new("100.64.0.0/10"),
      IPAddr.new("127.0.0.0/8"),
      IPAddr.new("169.254.0.0/16"),
      IPAddr.new("172.16.0.0/12"),
      IPAddr.new("192.0.0.0/24"),
      IPAddr.new("192.0.2.0/24"),
      IPAddr.new("192.168.0.0/16"),
      IPAddr.new("198.18.0.0/15"),
      IPAddr.new("198.51.100.0/24"),
      IPAddr.new("203.0.113.0/24"),
      IPAddr.new("224.0.0.0/4"),
      IPAddr.new("240.0.0.0/4"),
      IPAddr.new("255.255.255.255/32"),
      IPAddr.new("::1/128"),
      IPAddr.new("fc00::/7"),
      IPAddr.new("fe80::/10"),
      IPAddr.new("ff00::/8")
    ].freeze

    BLOCKED_HOSTS = %w[
      localhost
      metadata.google.internal
      metadata.google
      169.254.169.254
    ].freeze

    class SsrfError < StandardError; end

    def self.validate!(url)
      uri = URI.parse(url)
      host = uri.host.to_s.downcase

      raise SsrfError, "Only HTTP(S) URLs are allowed" unless %w[http https].include?(uri.scheme)
      raise SsrfError, "Blocked host: #{host}" if BLOCKED_HOSTS.include?(host)
      raise SsrfError, "Numeric IP addresses are not allowed" if host.match?(/\A\d{1,3}(\.\d{1,3}){3}\z/) || host.include?(":")

      begin
        addresses = Resolv.getaddresses(host)
        addresses.each do |addr|
          ip = IPAddr.new(addr)
          if BLOCKED_RANGES.any? { |range| range.include?(ip) }
            raise SsrfError, "Host #{host} resolves to a private or reserved IP address"
          end
        end
      rescue Resolv::ResolvError
        raise SsrfError, "Cannot resolve host: #{host}"
      end

      true
    end

    def self.safe?(url)
      validate!(url)
      true
    rescue SsrfError
      false
    end
  end
end
