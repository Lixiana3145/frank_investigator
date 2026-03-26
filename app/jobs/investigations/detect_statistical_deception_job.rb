module Investigations
  class DetectStatisticalDeceptionJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      @investigation = Investigation.includes(:root_article, claim_assessments: :claim).find(investigation_id)

      Pipeline::StepRunner.call(investigation: @investigation, name: "detect_statistical_deception", allow_rerun: true) do
        result = Analyzers::StatisticalDeceptionDetector.call(investigation: @investigation)

        deception_data = {
          deceptions: result.deceptions.map(&:to_h),
          statistical_integrity_score: result.statistical_integrity_score,
          summary: result.summary
        }

        @investigation.update!(statistical_deception: deception_data)

        { deceptions_found: result.deceptions.size, statistical_integrity_score: result.statistical_integrity_score }
      end
    ensure
      if @investigation
        Investigations::DetectSelectiveQuotationJob.perform_later(@investigation.id)
        Investigations::RefreshStatus.call(@investigation)
      end
    end
  end
end
