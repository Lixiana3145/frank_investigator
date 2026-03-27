module Investigations
  class GenerateSummaryJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      @investigation = Investigation.includes(:root_article, claim_assessments: :claim).find(investigation_id)

      Pipeline::StepRunner.call(investigation: @investigation, name: "generate_summary", allow_rerun: true) do
        result = Investigations::GenerateSummary.call(investigation: @investigation)

        summary_data = if result
          {
            conclusion: result.conclusion,
            strengths: result.strengths,
            weaknesses: result.weaknesses,
            overall_quality: result.overall_quality
          }
        end

        @investigation.update!(llm_summary: summary_data) if summary_data

        { overall_quality: summary_data&.dig(:overall_quality) }
      end
      @step_succeeded = true
    ensure
      if @investigation
        # Cross-reference is non-blocking enrichment — fire and forget
        Investigations::CrossReferenceJob.perform_later(@investigation.id) if @step_succeeded
        Investigations::RefreshStatus.call(@investigation)
      end
    end
  end
end
