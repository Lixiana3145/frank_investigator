module Investigations
  class AssessClaimsJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      investigation = Investigation.includes(:claim_assessments, :root_article).find(investigation_id)

      Pipeline::StepRunner.call(investigation:, name: "assess_claims") do
        ApplicationRecord.transaction do
          investigation.claim_assessments.includes(:claim).find_each do |assessment|
            result = Analyzers::ClaimAssessor.call(investigation:, claim: assessment.claim)
            assessment.update!(
              verdict: result.verdict,
              confidence_score: result.confidence_score,
              checkability_status: result.checkability_status,
              reason_summary: result.reason_summary,
              missing_evidence_summary: result.missing_evidence_summary,
              conflict_score: result.conflict_score,
              authority_score: result.authority_score,
              independence_score: result.independence_score,
              timeliness_score: result.timeliness_score
            )
          end
        end

        { assessed_claims_count: investigation.claim_assessments.count }
      end
    ensure
      Investigations::RefreshStatus.call(investigation) if investigation
    end
  end
end
