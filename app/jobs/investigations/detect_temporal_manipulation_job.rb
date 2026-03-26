module Investigations
  class DetectTemporalManipulationJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      @investigation = Investigation.includes(:root_article, claim_assessments: :claim).find(investigation_id)

      Pipeline::StepRunner.call(investigation: @investigation, name: "detect_temporal_manipulation", allow_rerun: true) do
        result = Analyzers::TemporalManipulationDetector.call(investigation: @investigation)

        temporal_data = {
          manipulations: result.manipulations.map(&:to_h),
          temporal_integrity_score: result.temporal_integrity_score,
          summary: result.summary
        }

        @investigation.update!(temporal_manipulation: temporal_data)

        { manipulations_found: result.manipulations.size, temporal_integrity_score: result.temporal_integrity_score }
      end
    ensure
      if @investigation
        Investigations::DetectStatisticalDeceptionJob.perform_later(@investigation.id)
        Investigations::RefreshStatus.call(@investigation)
      end
    end
  end
end
