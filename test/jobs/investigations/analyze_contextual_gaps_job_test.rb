require "test_helper"

class Investigations::AnalyzeContextualGapsJobTest < ActiveSupport::TestCase
  test "runs contextual gap analysis and stores result on investigation" do
    root = Article.create!(
      url: "https://gapjob.com/article", normalized_url: "https://gapjob.com/article",
      host: "gapjob.com", fetch_status: :fetched,
      body_text: "Article about fuel prices and innovation citing foreign studies.",
      title: "Fuel Price Article"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )
    claim = Claim.create!(canonical_text: "Higher prices spur innovation", canonical_fingerprint: "gj_#{SecureRandom.hex(4)}", checkability_status: :checkable)
    ClaimAssessment.create!(investigation:, claim:, verdict: :supported, confidence_score: 0.8, checkability_status: :checkable)

    Investigations::AnalyzeContextualGapsJob.perform_now(investigation.id)

    investigation.reload
    assert investigation.contextual_gaps.present?
    assert investigation.contextual_gaps.key?("gaps")
    assert investigation.contextual_gaps.key?("completeness_score")
    assert investigation.contextual_gaps.key?("summary")
  end

  test "creates pipeline step" do
    root = Article.create!(
      url: "https://gapjob2.com/article", normalized_url: "https://gapjob2.com/article",
      host: "gapjob2.com", fetch_status: :fetched,
      body_text: "Content.", title: "Test"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::AnalyzeContextualGapsJob.perform_now(investigation.id)

    step = investigation.pipeline_steps.find_by(name: "analyze_contextual_gaps")
    assert_equal "completed", step.status
  end
end
