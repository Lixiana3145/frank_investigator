module Investigations
  class DetectSourceMisrepresentationJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      @investigation = Investigation.includes(:root_article, claim_assessments: :claim).find(investigation_id)

      Pipeline::StepRunner.call(investigation: @investigation, name: "detect_source_misrepresentation", allow_rerun: true) do
        result = Analyzers::SourceMisrepresentationDetector.call(investigation: @investigation)

        misrepresentation_data = {
          misrepresentations: result.misrepresentations.map(&:to_h),
          misrepresentation_score: result.misrepresentation_score,
          summary: result.summary
        }

        @investigation.update!(source_misrepresentation: misrepresentation_data)

        { misrepresentations_found: result.misrepresentations.size, misrepresentation_score: result.misrepresentation_score }
      end
    ensure
      if @investigation
        Investigations::DetectTemporalManipulationJob.perform_later(@investigation.id)
        Investigations::RefreshStatus.call(@investigation)
      end
    end
  end
end
