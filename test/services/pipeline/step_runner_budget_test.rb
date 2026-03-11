require "test_helper"

class Pipeline::StepRunnerBudgetTest < ActiveSupport::TestCase
  test "enforces maximum step budget per investigation" do
    root = Article.create!(url: "https://a.com/budget", normalized_url: "https://a.com/budget", host: "a.com", fetch_status: :fetched)
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)

    # Create steps up to the limit
    Pipeline::StepRunner::MAX_STEPS_PER_INVESTIGATION.times do |i|
      investigation.pipeline_steps.create!(name: "step_#{i}", status: :completed, finished_at: Time.current)
    end

    assert_raises(Pipeline::StepRunner::BudgetExceededError) do
      Pipeline::StepRunner.call(investigation:, name: "one_too_many") { {} }
    end
  end

  test "allows steps within budget" do
    root = Article.create!(url: "https://a.com/ok-budget", normalized_url: "https://a.com/ok-budget", host: "a.com", fetch_status: :fetched)
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)

    result = Pipeline::StepRunner.call(investigation:, name: "within_budget") { { ok: true } }
    assert result.executed
    assert_equal "completed", result.step.status
  end
end
