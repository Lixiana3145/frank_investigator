module Investigations
  # Replaces 5 sequential LLM calls with a single batched call.
  # Runs: source misrepresentation, temporal manipulation, statistical deception,
  # selective quotation, and authority laundering in one LLM request.
  class BatchContentAnalysisJob < ApplicationJob
    queue_as :default

    STEP_COLUMNS = {
      "detect_source_misrepresentation" => :source_misrepresentation,
      "detect_temporal_manipulation" => :temporal_manipulation,
      "detect_statistical_deception" => :statistical_deception,
      "detect_selective_quotation" => :selective_quotation,
      "detect_authority_laundering" => :authority_laundering
    }.freeze

    def perform(investigation_id)
      @investigation = Investigation.includes(:root_article, claim_assessments: :claim).find(investigation_id)

      return if steps_currently_running?
      return if batch_steps_completed?

      # Run the batch analyzer (single LLM call)
      results = Analyzers::BatchContentAnalyzer.call(investigation: @investigation)

      # Store each result and create pipeline steps
      executed_results = []
      STEP_COLUMNS.each do |step_name, column|
        executed_results << Pipeline::StepRunner.call(investigation: @investigation, name: step_name, allow_rerun: true) do
          data = results[column]
          @investigation.update_column(column, data) if data
          { batched: true }
        end
      end
      @step_succeeded = executed_results.any?(&:executed)
    ensure
      if @investigation && @step_succeeded
        # Fan out: these 3 steps are independent and run in parallel
        Investigations::AnalyzeRhetoricalStructureJob.perform_later(@investigation.id)
        Investigations::AnalyzeContextualGapsJob.perform_later(@investigation.id)
        Investigations::DetectCoordinatedNarrativeJob.perform_later(@investigation.id)
      end
      Investigations::RefreshStatus.call(@investigation) if @investigation
    end

    private

    def batch_steps_completed?
      existing_steps = @investigation.pipeline_steps.where(name: STEP_COLUMNS.keys).index_by(&:name)
      STEP_COLUMNS.keys.all? { |name| existing_steps[name]&.completed? }
    end

    def steps_currently_running?
      @investigation.pipeline_steps.where(name: STEP_COLUMNS.keys, status: :running).where("started_at >= ?", Pipeline::StepRunner::STALE_AFTER.ago).exists?
    end
  end
end
