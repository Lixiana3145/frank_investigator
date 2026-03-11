module Investigations
  class AssessClaimsJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      @investigation = Investigation.includes(:claim_assessments, :root_article).find(investigation_id)

      Pipeline::StepRunner.call(investigation: @investigation, name: "assess_claims", allow_rerun: true) do
        ApplicationRecord.transaction do
          @investigation.claim_assessments.includes(:claim).find_each do |assessment|
            result = Analyzers::ClaimAssessor.call(investigation: @investigation, claim: assessment.claim)
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

            sync_evidence_items!(assessment)
          end
        end

        { assessed_claims_count: @investigation.claim_assessments.count }
      end
    ensure
      Investigations::RefreshStatus.call(@investigation) if @investigation
    end

    private

    def sync_evidence_items!(assessment)
      existing_urls = []

      assessment.claim.articles.fetched.where.not(id: @investigation.root_article_id).distinct.find_each do |article|
        existing_urls << article.normalized_url

        EvidenceItem.find_or_initialize_by(claim_assessment: assessment, source_url: article.normalized_url).tap do |item|
          item.article = article
          item.source_type = :article
          item.stance = :contextualizes
          item.published_at = article.published_at
          item.excerpt = article.excerpt
          item.citation_locator = article.main_content_path
          item.authority_score = assessment.authority_score
          item.independence_group = article.host
          item.save!
        end
      end

      assessment.evidence_items.where.not(source_url: existing_urls).destroy_all
    end
  end
end
