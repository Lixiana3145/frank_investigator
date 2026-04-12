require "test_helper"

class Investigations::BatchContentAnalysisJobTest < ActiveJob::TestCase
  test "does not fan out when all batch steps are already completed" do
    root = Article.create!(
      url: "https://example.com/batch-done",
      normalized_url: "https://example.com/batch-done",
      host: "example.com",
      fetch_status: :fetched,
      fetched_at: Time.current,
      title: "Done",
      body_text: "Done"
    )
    investigation = Investigation.create!(
      submitted_url: root.url,
      normalized_url: root.normalized_url,
      root_article: root,
      status: :processing
    )

    %w[
      detect_source_misrepresentation
      detect_temporal_manipulation
      detect_statistical_deception
      detect_selective_quotation
      detect_authority_laundering
    ].each do |step_name|
      investigation.pipeline_steps.create!(name: step_name, status: :completed, finished_at: Time.current)
    end

    assert_no_enqueued_jobs only: [
      Investigations::AnalyzeRhetoricalStructureJob,
      Investigations::AnalyzeContextualGapsJob,
      Investigations::DetectCoordinatedNarrativeJob
    ] do
      Investigations::BatchContentAnalysisJob.perform_now(investigation.id)
    end
  end
end
