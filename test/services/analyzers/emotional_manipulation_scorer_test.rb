require "test_helper"

class Analyzers::EmotionalManipulationScorerTest < ActiveSupport::TestCase
  setup do
    @root = Article.create!(
      url: "https://emtest.com/article", normalized_url: "https://emtest.com/article",
      host: "emtest.com", fetch_status: :fetched,
      body_text: "This is a crisis of catastrophic proportions. The scandal threatens everything. We must act immediately or face disaster.",
      title: "Catastrophic Crisis Threatens All"
    )
    @investigation = Investigation.create!(
      submitted_url: @root.url, normalized_url: @root.normalized_url,
      root_article: @root, status: :processing
    )
  end

  test "returns valid result" do
    result = Analyzers::EmotionalManipulationScorer.call(investigation: @investigation)

    assert_kind_of Analyzers::EmotionalManipulationScorer::Result, result
    assert_includes 0.0..1.0, result.emotional_temperature
    assert_includes 0.0..1.0, result.evidence_density
    assert_includes 0.0..1.0, result.manipulation_score
    assert_kind_of Array, result.dominant_emotions
    assert_kind_of Array, result.contributing_factors
    assert result.summary.present?
  end

  test "returns empty result when no body text" do
    @root.update!(body_text: nil)
    result = Analyzers::EmotionalManipulationScorer.call(investigation: @investigation)

    assert_equal 0.0, result.emotional_temperature
    assert_equal 1.0, result.evidence_density
    assert_equal 0.0, result.manipulation_score
    assert_equal [], result.dominant_emotions
    assert_equal [], result.contributing_factors
    assert result.summary.present?
  end

  test "result struct has expected fields" do
    result = Analyzers::EmotionalManipulationScorer.call(investigation: @investigation)

    assert_respond_to result, :emotional_temperature
    assert_respond_to result, :evidence_density
    assert_respond_to result, :manipulation_score
    assert_respond_to result, :dominant_emotions
    assert_respond_to result, :contributing_factors
    assert_respond_to result, :summary
  end
end
