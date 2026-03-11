require "uri"

module Investigations
  class UrlNormalizer
    class InvalidUrlError < StandardError; end

    def self.call(url)
      new(url).call
    end

    def initialize(url)
      @url = url.to_s.strip
    end

    def call
      raise InvalidUrlError, "URL cannot be blank" if @url.blank?

      uri = URI.parse(candidate_url)
      validate_http_url!(uri)

      uri.scheme = uri.scheme.downcase
      uri.host = uri.host.downcase
      uri.fragment = nil
      uri.port = nil if default_port?(uri)
      uri.path = "/" if uri.path.blank?
      uri.query = normalize_query(uri.query)

      normalized = uri.to_s
      normalized.end_with?("/") && uri.path == "/" && uri.query.blank? ? normalized.delete_suffix("/") : normalized
    rescue URI::InvalidURIError
      raise InvalidUrlError, "URL is not valid"
    end

    private

    def candidate_url
      @url.match?(/\Ahttps?:\/\//i) ? @url : "https://#{@url}"
    end

    def validate_http_url!(uri)
      raise InvalidUrlError, "URL is not valid" unless uri.is_a?(URI::HTTP) && uri.host.present?
    end

    def default_port?(uri)
      (uri.scheme == "http" && uri.port == 80) || (uri.scheme == "https" && uri.port == 443)
    end

    def normalize_query(query)
      return nil if query.blank?

      URI.encode_www_form(URI.decode_www_form(query).sort)
    end
  end
end
