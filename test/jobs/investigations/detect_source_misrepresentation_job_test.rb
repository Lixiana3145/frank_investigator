require "test_helper"

class Investigations::DetectSourceMisrepresentationJobTest < ActiveSupport::TestCase
  test "stores result on investigation" do
    root = Article.create!(
      url: "https://smjob.com/article", normalized_url: "https://smjob.com/article",
      host: "smjob.com", fetch_status: :fetched,
      body_text: "A study shows coffee causes cancer, according to Harvard researchers.",
      title: "Coffee Cancer Study"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectSourceMisrepresentationJob.perform_now(investigation.id)

    investigation.reload
    assert investigation.source_misrepresentation.present?
    assert investigation.source_misrepresentation.key?("misrepresentations")
    assert investigation.source_misrepresentation.key?("misrepresentation_score")
    assert investigation.source_misrepresentation.key?("summary")
  end

  test "creates pipeline step" do
    root = Article.create!(
      url: "https://smjob2.com/article", normalized_url: "https://smjob2.com/article",
      host: "smjob2.com", fetch_status: :fetched,
      body_text: "Content.", title: "Test"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectSourceMisrepresentationJob.perform_now(investigation.id)

    step = investigation.pipeline_steps.find_by(name: "detect_source_misrepresentation")
    assert_equal "completed", step.status
  end
end
