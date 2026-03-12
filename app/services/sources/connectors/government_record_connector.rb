module Sources
  module Connectors
    class GovernmentRecordConnector < BaseConnector
      DOCUMENT_REGEX = /\b(lei|medida provisoria|portaria|resolucao|resolução|pl|projeto de lei|acordao|acórdão)\b[^\n]{0,40}/i

      def extract
        Result.new(
          published_at: generic_published_at,
          source_kind: :government_record,
          authority_tier: :primary,
          authority_score: 0.98,
          metadata_json: {
            "connector" => "government_record",
            "site_name" => generic_site_name,
            "document_reference" => document_reference
          }.compact
        )
      end

      private

      def document_reference
        [ @title, @document.text ].join("\n").match(DOCUMENT_REGEX)&.to_s&.squish
      end
    end
  end
end
