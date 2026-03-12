module Sources
  module Connectors
    class CompanyFilingConnector < BaseConnector
      FORM_REGEX = /\b(10-K|10-Q|8-K|20-F|6-K|formulario de referencia|fato relevante)\b/i

      def extract
        Result.new(
          published_at: generic_published_at,
          source_kind: :company_filing,
          authority_tier: :primary,
          authority_score: 0.91,
          metadata_json: {
            "connector" => "company_filing",
            "site_name" => generic_site_name,
            "filing_type" => filing_type
          }.compact
        )
      end

      private

      def filing_type
        [ @title, @document.text ].join("\n").match(FORM_REGEX)&.to_s&.upcase
      end
    end
  end
end
