module Investigations
  class ExtractClaimsJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      investigation = Investigation.includes(:root_article).find(investigation_id)

      Pipeline::StepRunner.call(investigation:, name: "extract_claims") do
        article = investigation.root_article || raise("Investigation is missing a root article")
        Articles::SyncClaims.call(investigation:, article:)

        AssessClaimsJob.perform_later(investigation.id)
        { claims_count: investigation.claim_assessments.count }
      end
    ensure
      Investigations::RefreshStatus.call(investigation) if investigation
    end
  end
end
