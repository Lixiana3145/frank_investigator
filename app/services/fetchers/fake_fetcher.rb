module Fetchers
  class FakeFetcher
    Snapshot = Struct.new(:html, :title, keyword_init: true)

    class << self
      def register(url, html:, title: nil)
        registry[Investigations::UrlNormalizer.call(url)] = Snapshot.new(html:, title:)
      end

      def clear
        registry.clear
      end

      def call(url)
        registry.fetch(Investigations::UrlNormalizer.call(url))
      end

      private

      def registry
        @registry ||= {}
      end
    end
  end
end
