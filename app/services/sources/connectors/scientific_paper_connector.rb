module Sources
  module Connectors
    class ScientificPaperConnector < BaseConnector
      DOI_REGEX = %r{\b10\.\d{4,9}/[-._;()/:A-Z0-9]+\b}i

      def extract
        Result.new(
          published_at: generic_published_at,
          source_kind: :scientific_paper,
          authority_tier: :primary,
          authority_score: 0.93,
          metadata_json: {
            "connector" => "scientific_paper",
            "site_name" => generic_site_name,
            "doi" => doi,
            "abstract" => abstract
          }.compact
        )
      end

      private

      def doi
        meta_value("meta[name='citation_doi']") || @document.text.match(DOI_REGEX)&.to_s
      end

      def abstract
        meta_value("meta[name='description']") || @document.at_css(".abstract, section.abstract, #abstract")&.text.to_s.squish.presence
      end
    end
  end
end
