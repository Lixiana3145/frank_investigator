module Analyzers
  class ClaimExtractor
    Result = Struct.new(:canonical_text, :surface_text, :role, :checkability_status, :importance_score, keyword_init: true)

    def self.call(article)
      new(article).call
    end

    def initialize(article)
      @article = article
    end

    def call
      candidates = []
      candidates.concat(extract_title_claims)
      candidates.concat(extract_body_claims)

      candidates.uniq { |result| ClaimFingerprint.call(result.canonical_text) }
    end

    private

    def extract_title_claims
      return [] if @article.title.blank?

      result = build_result(@article.title, role: :headline, importance_score: 1.0)
      result ? [result] : []
    end

    def extract_body_claims
      sentences.first(6).filter_map.with_index do |sentence, index|
        build_result(sentence, role: index.zero? ? :lead : :body, importance_score: index.zero? ? 0.85 : 0.65)
      end
    end

    def build_result(sentence, role:, importance_score:)
      surface_text = sentence.to_s.squish
      return nil if surface_text.blank? || surface_text.length < 30

      Result.new(
        canonical_text: surface_text,
        surface_text:,
        role:,
        checkability_status: CheckabilityClassifier.call(surface_text),
        importance_score:
      )
    end

    def sentences
      text = @article.body_text.to_s.squish
      return [] if text.blank?

      text.split(/(?<=[.!?])\s+/).map(&:strip)
    end
  end
end
