module Sources
  module Connectors
    class NewsArticleConnector < BaseConnector
      def initialize(url:, host:, title:, html:, source_kind:, authority_tier:, authority_score:)
        super(url:, host:, title:, html:)
        @source_kind = source_kind
        @authority_tier = authority_tier
        @authority_score = authority_score
      end

      def extract
        Result.new(
          published_at: generic_published_at,
          source_kind: @source_kind,
          authority_tier: @authority_tier,
          authority_score: @authority_score,
          metadata_json: {
            "connector" => "news_article",
            "site_name" => generic_site_name
          }.compact
        )
      end
    end
  end
end
