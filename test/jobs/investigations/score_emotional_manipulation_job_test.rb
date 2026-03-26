require "test_helper"

class Investigations::ScoreEmotionalManipulationJobTest < ActiveSupport::TestCase
  test "stores result on investigation" do
    root = Article.create!(
      url: "https://emjob.com/article", normalized_url: "https://emjob.com/article",
      host: "emjob.com", fetch_status: :fetched,
      body_text: "This is a crisis of catastrophic proportions. We must act immediately or face disaster.",
      title: "Catastrophic Crisis"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::ScoreEmotionalManipulationJob.perform_now(investigation.id)

    investigation.reload
    assert investigation.emotional_manipulation.present?
    assert investigation.emotional_manipulation.key?("emotional_temperature")
    assert investigation.emotional_manipulation.key?("evidence_density")
    assert investigation.emotional_manipulation.key?("manipulation_score")
    assert investigation.emotional_manipulation.key?("dominant_emotions")
    assert investigation.emotional_manipulation.key?("contributing_factors")
    assert investigation.emotional_manipulation.key?("summary")
  end

  test "creates pipeline step" do
    root = Article.create!(
      url: "https://emjob2.com/article", normalized_url: "https://emjob2.com/article",
      host: "emjob2.com", fetch_status: :fetched,
      body_text: "Content.", title: "Test"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::ScoreEmotionalManipulationJob.perform_now(investigation.id)

    step = investigation.pipeline_steps.find_by(name: "score_emotional_manipulation")
    assert_equal "completed", step.status
  end
end
