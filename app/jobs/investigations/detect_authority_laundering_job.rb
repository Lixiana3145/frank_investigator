module Investigations
  class DetectAuthorityLaunderingJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      @investigation = Investigation.includes(:root_article, claim_assessments: :claim).find(investigation_id)

      Pipeline::StepRunner.call(investigation: @investigation, name: "detect_authority_laundering", allow_rerun: true) do
        result = Analyzers::AuthorityLaunderingDetector.call(investigation: @investigation)

        laundering_data = {
          chains: result.chains.map(&:to_h),
          laundering_score: result.laundering_score,
          circular_citations_found: result.circular_citations_found,
          summary: result.summary
        }

        @investigation.update!(authority_laundering: laundering_data)

        { chains_found: result.chains.size, laundering_score: result.laundering_score, circular_citations_found: result.circular_citations_found }
      end
    ensure
      if @investigation
        Investigations::AnalyzeRhetoricalStructureJob.perform_later(@investigation.id)
        Investigations::RefreshStatus.call(@investigation)
      end
    end
  end
end
