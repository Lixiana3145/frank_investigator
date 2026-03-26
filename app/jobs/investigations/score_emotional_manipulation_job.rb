module Investigations
  class ScoreEmotionalManipulationJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      @investigation = Investigation.includes(:root_article, claim_assessments: :claim).find(investigation_id)

      Pipeline::StepRunner.call(investigation: @investigation, name: "score_emotional_manipulation", allow_rerun: true) do
        result = Analyzers::EmotionalManipulationScorer.call(investigation: @investigation)

        emotional_data = {
          emotional_temperature: result.emotional_temperature,
          evidence_density: result.evidence_density,
          manipulation_score: result.manipulation_score,
          dominant_emotions: result.dominant_emotions,
          contributing_factors: result.contributing_factors,
          summary: result.summary
        }

        @investigation.update!(emotional_manipulation: emotional_data)

        { manipulation_score: result.manipulation_score, emotional_temperature: result.emotional_temperature }
      end
      @step_succeeded = true
    ensure
      if @investigation
        Investigations::GenerateSummaryJob.perform_later(@investigation.id) if @step_succeeded
        Investigations::RefreshStatus.call(@investigation)
      end
    end
  end
end
