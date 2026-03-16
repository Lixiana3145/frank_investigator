require "net/http"
require "uri"
require "nokogiri"
require "digest"

module Fetchers
  class WebSearcher
    SearchResult = Struct.new(:url, :title, :snippet, keyword_init: true)
    MAX_RESULTS = 8
    HTTP_TIMEOUT = 10
    CACHE_TTL = 24.hours

    USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36"

    def self.call(query:, max_results: MAX_RESULTS)
      new(query:, max_results:).call
    end

    def initialize(query:, max_results:)
      @query = query.to_s.strip
      @max_results = max_results
    end

    def call
      return [] if @query.blank?

      cache_key = "web_search:#{Digest::SHA256.hexdigest(@query)}"
      cached = Rails.cache.read(cache_key)
      return cached.first(@max_results) if cached

      results = []
      results.concat(search_duckduckgo_html)
      results.concat(search_google_news_rss) if results.size < @max_results

      results = results.uniq { |r| r.url }
      results = filter_article_urls(results)
      results = results.first(@max_results)

      Rails.cache.write(cache_key, results, expires_in: CACHE_TTL)
      results
    end

    private

    def search_duckduckgo_html
      uri = URI("https://html.duckduckgo.com/html/")
      uri.query = URI.encode_www_form(q: @query)

      html = http_get(uri)
      return [] unless html

      doc = Nokogiri::HTML(html)
      doc.css("a.result__a").filter_map do |link|
        raw_href = link["href"].to_s
        url = extract_ddg_url(raw_href)
        next unless url

        title = link.text.to_s.strip
        snippet_node = link.ancestors("div").first&.at_css(".result__snippet")
        snippet = snippet_node&.text.to_s.strip

        SearchResult.new(url:, title:, snippet:)
      end
    rescue StandardError => e
      Rails.logger.warn("[WebSearcher] DuckDuckGo search failed: #{e.message}")
      []
    end

    def search_google_news_rss
      uri = URI("https://news.google.com/rss/search")
      uri.query = URI.encode_www_form(q: @query, hl: "pt-BR", gl: "BR", ceid: "BR:pt-419")

      xml = http_get(uri)
      return [] unless xml

      doc = Nokogiri::XML(xml)
      doc.css("item").filter_map do |item|
        url = item.at_css("link")&.text.to_s.strip
        next if url.blank?

        # Google News RSS wraps URLs; follow redirect if needed
        url = resolve_google_news_url(url)
        next unless url

        title = item.at_css("title")&.text.to_s.strip
        snippet = item.at_css("description")&.text.to_s.strip

        SearchResult.new(url:, title:, snippet:)
      end
    rescue StandardError => e
      Rails.logger.warn("[WebSearcher] Google News RSS search failed: #{e.message}")
      []
    end

    def extract_ddg_url(raw_href)
      return nil if raw_href.blank?

      if raw_href.include?("uddg=")
        uri = URI.parse(raw_href)
        params = URI.decode_www_form(uri.query.to_s)
        uddg = params.find { |k, _| k == "uddg" }&.last
        return normalize_search_url(uddg) if uddg
      end

      return nil if raw_href.start_with?("/") || raw_href.include?("duckduckgo.com")

      normalize_search_url(raw_href)
    rescue URI::InvalidURIError
      nil
    end

    def resolve_google_news_url(url)
      # Google News RSS sometimes uses direct URLs, sometimes redirects
      return normalize_search_url(url) unless url.include?("news.google.com")

      # For Google News redirect URLs, try to follow the redirect
      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
        http.head(uri.request_uri)
      end

      if response.is_a?(Net::HTTPRedirection) && response["location"]
        normalize_search_url(response["location"])
      else
        normalize_search_url(url)
      end
    rescue StandardError
      normalize_search_url(url)
    end

    def normalize_search_url(url)
      return nil if url.blank?

      url = CGI.unescape(url) if url.include?("%")
      uri = URI.parse(url)
      return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      return nil if uri.host.blank?

      Investigations::UrlNormalizer.call(url)
    rescue URI::InvalidURIError, Investigations::UrlNormalizer::InvalidUrlError
      nil
    end

    def filter_article_urls(results)
      results.select do |result|
        Investigations::UrlClassifier.call(result.url)
      rescue Investigations::UrlClassifier::RejectedUrlError
        false
      end
    end

    def http_get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = HTTP_TIMEOUT
      http.read_timeout = HTTP_TIMEOUT

      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      request["Accept-Language"] = "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7"

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        redirect_uri = URI.parse(response["location"])
        redirect_uri = URI.join(uri, redirect_uri) unless redirect_uri.absolute?
        http_get(redirect_uri)
      else
        Rails.logger.warn("[WebSearcher] HTTP #{response.code} from #{uri.host}")
        nil
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
      Rails.logger.warn("[WebSearcher] HTTP error: #{e.message}")
      nil
    end
  end
end
