module Fetchers
  class FakeFetcher
    Snapshot = Struct.new(:html, :title, keyword_init: true)

    class << self
      def register(url_or_pattern, html_or_content = nil, title_arg = nil, html: nil, title: nil)
        actual_html = html || html_or_content
        actual_title = title || title_arg

        if url_or_pattern.is_a?(Regexp)
          pattern_registry << { pattern: url_or_pattern, snapshot: Snapshot.new(html: actual_html, title: actual_title) }
        else
          registry[Investigations::UrlNormalizer.call(url_or_pattern)] = Snapshot.new(html: actual_html, title: actual_title)
        end
      end

      def clear
        registry.clear
        pattern_registry.clear
      end

      def call(url)
        new.call(url)
      end

      def lookup(url)
        normalized = begin
          Investigations::UrlNormalizer.call(url)
        rescue StandardError
          url
        end

        registry[normalized] || pattern_registry.find { |entry| url.match?(entry[:pattern]) }&.dig(:snapshot) ||
          raise(KeyError, "FakeFetcher: no match for #{url}")
      end

      private

      def registry
        @registry ||= {}
      end

      def pattern_registry
        @pattern_registry ||= []
      end
    end

    def call(url)
      self.class.lookup(url)
    end
  end
end
