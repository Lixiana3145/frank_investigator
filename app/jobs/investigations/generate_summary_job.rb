module Investigations
  class GenerateSummaryJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      @investigation = Investigation.includes(:root_article, claim_assessments: :claim).find(investigation_id)

      result = Pipeline::StepRunner.call(investigation: @investigation, name: "generate_summary", allow_rerun: true) do
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
      if result.executed
        # Generate honest headline after summary (has full context)
        honest = Analyzers::HonestHeadlineGenerator.call(investigation: @investigation)
        @investigation.update_column(:honest_headline, honest) if honest
      end

      @step_succeeded = result.executed
    ensure
      if @investigation
        # Cross-reference is non-blocking enrichment — fire and forget
        Investigations::CrossReferenceJob.perform_later(@investigation.id) if @step_succeeded
        Investigations::RefreshStatus.call(@investigation)
      end
    end
  end
end
