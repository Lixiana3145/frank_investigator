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
      validate_ssrf_safe!(uri)

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

    def validate_ssrf_safe!(uri)
      Security::SsrfValidator.validate!(uri.to_s)
    rescue Security::SsrfValidator::SsrfError => e
      raise InvalidUrlError, e.message
    end

    def default_port?(uri)
      (uri.scheme == "http" && uri.port == 80) || (uri.scheme == "https" && uri.port == 443)
    end

    # Tracking, analytics, and campaign parameters that don't affect content
    JUNK_PARAMS = %r{\A(
      utm_\w+          |  # Google Analytics campaign tracking
      fbclid           |  # Facebook click ID
      gclid            |  # Google Ads click ID
      gclsrc           |  # Google Ads click source
      dclid            |  # DoubleClick click ID
      msclkid          |  # Microsoft Ads click ID
      twclid           |  # Twitter click ID
      li_fat_id        |  # LinkedIn first-party ad tracking
      mc_cid           |  # Mailchimp campaign ID
      mc_eid           |  # Mailchimp email ID
      _ga              |  # Google Analytics client ID
      _gl              |  # Google cross-domain linker
      _hsenc           |  # HubSpot email tracking
      _hsmi            |  # HubSpot email tracking
      hsa_\w+          |  # HubSpot ad tracking
      ref              |  # Generic referrer
      referer          |  # Misspelled referrer
      source           |  # Generic source (not data source)
      trk              |  # LinkedIn tracking
      trkCampaign      |  # LinkedIn campaign tracking
      spm              |  # Alibaba/AliExpress tracking
      vero_id          |  # Vero email tracking
      wickedid         |  # Wicked Reports tracking
      yclid            |  # Yandex click ID
      __twitter_impression |  # Twitter impression tracking
      s_cid            |  # Adobe Analytics campaign
      s_kwcid          |  # Adobe Analytics keyword
      sa_\w+           |  # ShareASale tracking
      igshid           |  # Instagram share ID
      si               |  # Spotify share ID
      feature          |  # YouTube share feature
      app              |  # App source tracking
      sfnsn            |  # Social share tracking
      wp_.*            |  # WordPress campaign tracking
      amp              |  # AMP tracking flag
      __cf_chl_\w+     |  # Cloudflare challenge tokens
      _openstat           # Openstat tracking
    )\z}xi

    def normalize_query(query)
      return nil if query.blank?

      cleaned = URI.decode_www_form(query)
        .reject { |key, _| key.match?(JUNK_PARAMS) }
        .sort

      cleaned.empty? ? nil : URI.encode_www_form(cleaned)
    end
  end
end
