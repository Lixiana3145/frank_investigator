module Articles
  class SyncClaims
    def self.call(investigation:, article:)
      new(investigation:, article:).call
    end

    def initialize(investigation:, article:)
      @investigation = investigation
      @article = article
    end

    def call
      Analyzers::ClaimExtractor.call(@article).each do |result|
        fingerprint = Analyzers::ClaimFingerprint.call(result.canonical_text)
        claim = Claim.find_or_initialize_by(canonical_fingerprint: fingerprint)
        claim.update!(
          canonical_text: result.canonical_text,
          checkability_status: result.checkability_status,
          first_seen_at: claim.first_seen_at || Time.current,
          last_seen_at: Time.current
        )

        ArticleClaim.find_or_initialize_by(article: @article, claim:, role: result.role).tap do |record|
          record.surface_text = result.surface_text
          record.importance_score = result.importance_score
          record.title_related = result.role.to_s == "headline"
          record.save!
        end

        ClaimAssessment.find_or_initialize_by(investigation: @investigation, claim:).save!
      end
    end
  end
end
