require "test_helper"

class Llm::ConsensusStrictnessTest < ActiveSupport::TestCase
  test "unanimous models get no penalty" do
    client = Llm::RubyLlmClient.new(models: ["model-a", "model-b"])
    results = [
      Llm::RubyLlmClient::Result.new(verdict: "supported", confidence_score: 0.85, reason_summary: "Evidence supports."),
      Llm::RubyLlmClient::Result.new(verdict: "supported", confidence_score: 0.90, reason_summary: "Confirmed by data.")
    ]

    aggregated = client.send(:aggregate_results, results)
    assert_equal "supported", aggregated.verdict
    assert aggregated.unanimous
    assert_in_delta 0.875, aggregated.confidence_score, 0.01
    assert_includes aggregated.disagreement_details, "All models agree"
  end

  test "adjacent verdict pair gets 0.08 penalty" do
    client = Llm::RubyLlmClient.new(models: ["model-a", "model-b"])
    results = [
      Llm::RubyLlmClient::Result.new(verdict: "supported", confidence_score: 0.80, reason_summary: "Looks supported."),
      Llm::RubyLlmClient::Result.new(verdict: "mixed", confidence_score: 0.70, reason_summary: "Mixed evidence.")
    ]

    aggregated = client.send(:aggregate_results, results)
    refute aggregated.unanimous
    # Mean confidence = 0.75, penalty = 0.08, expected ~0.67
    assert_in_delta 0.67, aggregated.confidence_score, 0.01
    assert_includes aggregated.disagreement_details, "Models disagree"
  end

  test "opposed verdict pair gets 0.15 penalty" do
    client = Llm::RubyLlmClient.new(models: ["model-a", "model-b"])
    results = [
      Llm::RubyLlmClient::Result.new(verdict: "supported", confidence_score: 0.85, reason_summary: "Confirmed."),
      Llm::RubyLlmClient::Result.new(verdict: "disputed", confidence_score: 0.80, reason_summary: "Contradicted.")
    ]

    aggregated = client.send(:aggregate_results, results)
    refute aggregated.unanimous
    # Mean confidence = 0.825, penalty = 0.15, expected ~0.675
    assert_in_delta 0.675, aggregated.confidence_score, 0.01
  end

  test "three different verdicts get 0.25 penalty" do
    client = Llm::RubyLlmClient.new(models: ["model-a", "model-b", "model-c"])
    results = [
      Llm::RubyLlmClient::Result.new(verdict: "supported", confidence_score: 0.80, reason_summary: "Yes."),
      Llm::RubyLlmClient::Result.new(verdict: "mixed", confidence_score: 0.60, reason_summary: "Maybe."),
      Llm::RubyLlmClient::Result.new(verdict: "disputed", confidence_score: 0.70, reason_summary: "No.")
    ]

    aggregated = client.send(:aggregate_results, results)
    refute aggregated.unanimous
    # Mean confidence = 0.7, penalty = 0.25, expected ~0.45
    assert_in_delta 0.45, aggregated.confidence_score, 0.01
  end

  test "quarantined models are excluded" do
    ENV["QUARANTINED_MODELS"] = "bad-model"
    client = Llm::RubyLlmClient.new(models: ["good-model", "bad-model", "another-good-model"])
    assert_equal ["good-model", "another-good-model"], client.instance_variable_get(:@models)
  ensure
    ENV.delete("QUARANTINED_MODELS")
  end

  test "disagreement details include per-model verdicts" do
    client = Llm::RubyLlmClient.new(models: ["model-a", "model-b"])
    results = [
      Llm::RubyLlmClient::Result.new(verdict: "supported", confidence_score: 0.85, reason_summary: "Good."),
      Llm::RubyLlmClient::Result.new(verdict: "disputed", confidence_score: 0.70, reason_summary: "Bad.")
    ]

    aggregated = client.send(:aggregate_results, results)
    assert_includes aggregated.disagreement_details, "supported"
    assert_includes aggregated.disagreement_details, "disputed"
    assert_includes aggregated.disagreement_details, "85%"
    assert_includes aggregated.disagreement_details, "70%"
  end

  test "model_results contains per-model data" do
    client = Llm::RubyLlmClient.new(models: ["model-a", "model-b"])
    results = [
      Llm::RubyLlmClient::Result.new(verdict: "supported", confidence_score: 0.85, reason_summary: "Good."),
      Llm::RubyLlmClient::Result.new(verdict: "disputed", confidence_score: 0.70, reason_summary: "Bad.")
    ]

    aggregated = client.send(:aggregate_results, results)
    assert_equal 2, aggregated.model_results.size
    assert_equal "supported", aggregated.model_results[0][:verdict]
    assert_equal "disputed", aggregated.model_results[1][:verdict]
  end

  test "result struct has disagreement_details and unanimous fields" do
    result = Llm::RubyLlmClient::Result.new(
      verdict: "supported",
      confidence_score: 0.9,
      reason_summary: "Test",
      model_results: [],
      disagreement_details: "All agree",
      unanimous: true
    )
    assert result.unanimous
    assert_equal "All agree", result.disagreement_details
  end

  test "claim assessment model has llm_interactions association" do
    root = Article.create!(url: "https://example.com/consensus-test", normalized_url: "https://example.com/consensus-test", host: "example.com", fetch_status: :fetched)
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)
    claim = Claim.create!(canonical_text: "Consensus test claim.", canonical_fingerprint: "consensus test claim unique fp", checkability_status: :checkable)
    assessment = ClaimAssessment.create!(investigation:, claim:)

    interaction = LlmInteraction.create!(
      investigation:,
      claim_assessment: assessment,
      interaction_type: :assessment,
      model_id: "test-model",
      prompt_text: "test prompt",
      status: :completed,
      response_json: { "verdict" => "supported", "confidence_score" => 0.85, "reason_summary" => "Good" }
    )

    assert_includes assessment.reload.llm_interactions, interaction
  end
end
