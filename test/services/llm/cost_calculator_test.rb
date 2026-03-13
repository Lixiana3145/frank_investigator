require "test_helper"

class Llm::CostCalculatorTest < ActiveSupport::TestCase
  test "calculates cost for known model" do
    cost = Llm::CostCalculator.call(
      model_id: "openai/gpt-5-mini",
      prompt_tokens: 1000,
      completion_tokens: 500
    )
    # input: 1000/1M * 0.40 = 0.0004, output: 500/1M * 1.60 = 0.0008
    assert_in_delta 0.0012, cost, 0.000001
  end

  test "calculates cost for expensive model" do
    cost = Llm::CostCalculator.call(
      model_id: "anthropic/claude-3.7-sonnet",
      prompt_tokens: 10_000,
      completion_tokens: 2_000
    )
    # input: 10000/1M * 3.00 = 0.03, output: 2000/1M * 15.00 = 0.03
    assert_in_delta 0.06, cost, 0.000001
  end

  test "uses default pricing for unknown model" do
    cost = Llm::CostCalculator.call(
      model_id: "some/unknown-model",
      prompt_tokens: 1000,
      completion_tokens: 1000
    )
    # input: 1000/1M * 1.00 = 0.001, output: 1000/1M * 5.00 = 0.005
    assert_in_delta 0.006, cost, 0.000001
  end

  test "handles nil tokens gracefully" do
    cost = Llm::CostCalculator.call(
      model_id: "openai/gpt-5-mini",
      prompt_tokens: nil,
      completion_tokens: nil
    )
    assert_equal 0, cost
  end

  test "compute_for_interaction! updates cost_usd on completed interaction" do
    article = Article.create!(url: "https://example.com/cost-test", normalized_url: "https://example.com/cost-test", host: "example.com")
    investigation = Investigation.create!(submitted_url: article.url, normalized_url: article.normalized_url, root_article: article)

    interaction = LlmInteraction.create!(
      investigation: investigation,
      model_id: "openai/gpt-5-mini",
      prompt_text: "test prompt",
      status: :completed,
      prompt_tokens: 1000,
      completion_tokens: 500
    )

    cost = Llm::CostCalculator.compute_for_interaction!(interaction)
    assert_in_delta 0.0012, cost, 0.000001
    assert_in_delta 0.0012, interaction.reload.cost_usd.to_f, 0.000001
  end
end
