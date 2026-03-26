require "test_helper"

class Investigations::DetectCoordinatedNarrativeJobTest < ActiveSupport::TestCase
  test "runs coordinated narrative detection and stores result" do
    root = Article.create!(
      url: "https://cnjob.com/article", normalized_url: "https://cnjob.com/article",
      host: "cnjob.com", fetch_status: :fetched,
      body_text: "Article about a media controversy with coordinated coverage patterns.",
      title: "Media Controversy"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectCoordinatedNarrativeJob.perform_now(investigation.id)

    investigation.reload
    assert investigation.coordinated_narrative.present?
    assert investigation.coordinated_narrative.key?("coordination_score")
    assert investigation.coordinated_narrative.key?("pattern_summary")
  end

  test "creates pipeline step" do
    root = Article.create!(
      url: "https://cnjob2.com/article", normalized_url: "https://cnjob2.com/article",
      host: "cnjob2.com", fetch_status: :fetched,
      body_text: "Content.", title: "Test"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectCoordinatedNarrativeJob.perform_now(investigation.id)

    step = investigation.pipeline_steps.find_by(name: "detect_coordinated_narrative")
    assert_equal "completed", step.status
  end
end
