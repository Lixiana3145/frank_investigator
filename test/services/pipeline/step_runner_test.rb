require "test_helper"

class Pipeline::StepRunnerTest < ActiveSupport::TestCase
  test "executes a completed step only once" do
    article = Article.create!(url: "https://example.com/a", normalized_url: "https://example.com/a", host: "example.com")
    investigation = Investigation.create!(submitted_url: article.url, normalized_url: article.normalized_url, root_article: article)
    executions = 0

    2.times do
      Pipeline::StepRunner.call(investigation:, name: "fetch_root_article") do
        executions += 1
        { ok: true }
      end
    end

    assert_equal 1, executions
    assert_equal "completed", investigation.pipeline_steps.find_by!(name: "fetch_root_article").status
  end
end
