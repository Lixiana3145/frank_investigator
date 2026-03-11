module Investigations
  class ExtractClaimsJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      investigation = Investigation.includes(:root_article).find(investigation_id)

      Pipeline::StepRunner.call(investigation:, name: "extract_claims") do
        article = investigation.root_article || raise("Investigation is missing a root article")
        results = Analyzers::ClaimExtractor.call(article)

        ApplicationRecord.transaction do
          results.each do |result|
            fingerprint = Analyzers::ClaimFingerprint.call(result.canonical_text)
            claim = Claim.find_or_initialize_by(canonical_fingerprint: fingerprint)
            claim.update!(
              canonical_text: result.canonical_text,
              checkability_status: result.checkability_status,
              first_seen_at: claim.first_seen_at || Time.current,
              last_seen_at: Time.current
            )

            ArticleClaim.find_or_initialize_by(article:, claim:, role: result.role).tap do |record|
              record.surface_text = result.surface_text
              record.importance_score = result.importance_score
              record.title_related = result.role.to_s == "headline"
              record.save!
            end

            ClaimAssessment.find_or_initialize_by(investigation:, claim:).save!
          end
        end

        AssessClaimsJob.perform_later(investigation.id)
        { claims_count: investigation.claim_assessments.count }
      end
    ensure
      Investigations::RefreshStatus.call(investigation) if investigation
    end
  end
end
