module Investigations
  class KickoffJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      investigation = Investigation.find(investigation_id)

      Pipeline::StepRunner.call(investigation:, name: "kickoff") do
        investigation.update!(status: :processing)
        FetchRootArticleJob.perform_later(investigation.id)
        {}
      end
    ensure
      Investigations::RefreshStatus.call(investigation) if investigation
    end
  end
end
