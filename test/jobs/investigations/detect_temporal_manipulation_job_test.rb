require "test_helper"

class Investigations::DetectTemporalManipulationJobTest < ActiveSupport::TestCase
  test "stores result on investigation" do
    root = Article.create!(
      url: "https://tmjob.com/article", normalized_url: "https://tmjob.com/article",
      host: "tmjob.com", fetch_status: :fetched,
      body_text: "Unemployment is at 12%, according to data from 2019. The economy struggles recently.",
      title: "Economy Article"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectTemporalManipulationJob.perform_now(investigation.id)

    investigation.reload
    assert investigation.temporal_manipulation.present?
    assert investigation.temporal_manipulation.key?("manipulations")
    assert investigation.temporal_manipulation.key?("temporal_integrity_score")
    assert investigation.temporal_manipulation.key?("summary")
  end

  test "creates pipeline step" do
    root = Article.create!(
      url: "https://tmjob2.com/article", normalized_url: "https://tmjob2.com/article",
      host: "tmjob2.com", fetch_status: :fetched,
      body_text: "Content.", title: "Test"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectTemporalManipulationJob.perform_now(investigation.id)

    step = investigation.pipeline_steps.find_by(name: "detect_temporal_manipulation")
    assert_equal "completed", step.status
  end
end
