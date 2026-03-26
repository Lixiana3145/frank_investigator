require "test_helper"

class Investigations::DetectStatisticalDeceptionJobTest < ActiveSupport::TestCase
  test "stores result on investigation" do
    root = Article.create!(
      url: "https://sdjob.com/article", normalized_url: "https://sdjob.com/article",
      host: "sdjob.com", fetch_status: :fetched,
      body_text: "Sales grew 300% last quarter. Crime rose by 40% compared to last year.",
      title: "Shocking Numbers"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectStatisticalDeceptionJob.perform_now(investigation.id)

    investigation.reload
    assert investigation.statistical_deception.present?
    assert investigation.statistical_deception.key?("deceptions")
    assert investigation.statistical_deception.key?("statistical_integrity_score")
    assert investigation.statistical_deception.key?("summary")
  end

  test "creates pipeline step" do
    root = Article.create!(
      url: "https://sdjob2.com/article", normalized_url: "https://sdjob2.com/article",
      host: "sdjob2.com", fetch_status: :fetched,
      body_text: "Content.", title: "Test"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectStatisticalDeceptionJob.perform_now(investigation.id)

    step = investigation.pipeline_steps.find_by(name: "detect_statistical_deception")
    assert_equal "completed", step.status
  end
end
