module Sources
  module Connectors
    class PressReleaseConnector < BaseConnector
      def extract
        Result.new(
          published_at: generic_published_at,
          source_kind: :press_release,
          authority_tier: :primary,
          authority_score: 0.76,
          metadata_json: {
            "connector" => "press_release",
            "site_name" => generic_site_name,
            "issuer" => issuer
          }.compact
        )
      end

      private

      def issuer
        generic_site_name || @title.split(/[-|:]/).first.to_s.squish.presence
      end
    end
  end
end
