module Investigations
  class DetectSelectiveQuotationJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      @investigation = Investigation.includes(:root_article, claim_assessments: :claim).find(investigation_id)

      Pipeline::StepRunner.call(investigation: @investigation, name: "detect_selective_quotation", allow_rerun: true) do
        result = Analyzers::SelectiveQuotationDetector.call(investigation: @investigation)

        quotation_data = {
          quotations: result.quotations.map(&:to_h),
          quotation_integrity_score: result.quotation_integrity_score,
          summary: result.summary
        }

        @investigation.update!(selective_quotation: quotation_data)

        { quotations_found: result.quotations.size, quotation_integrity_score: result.quotation_integrity_score }
      end
    ensure
      if @investigation
        Investigations::DetectAuthorityLaunderingJob.perform_later(@investigation.id)
        Investigations::RefreshStatus.call(@investigation)
      end
    end
  end
end
