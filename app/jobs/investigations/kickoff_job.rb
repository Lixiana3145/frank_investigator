module Investigations
  class KickoffJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      @investigation = Investigation.find(investigation_id)

      result = Pipeline::StepRunner.call(investigation: @investigation, name: "kickoff") do
        @investigation.update!(status: :processing)
        {}
      end
      @step_succeeded = result.executed
    ensure
      if @investigation
        Investigations::FetchRootArticleJob.perform_later(@investigation.id) if @step_succeeded
        Investigations::RefreshStatus.call(@investigation)
      end
    end
  end
end
