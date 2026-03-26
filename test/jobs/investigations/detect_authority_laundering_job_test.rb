require "test_helper"

class Investigations::DetectAuthorityLaunderingJobTest < ActiveSupport::TestCase
  test "stores result on investigation" do
    root = Article.create!(
      url: "https://aljob.com/article", normalized_url: "https://aljob.com/article",
      host: "aljob.com", fetch_status: :fetched,
      body_text: "According to reports, the scandal was first reported by a small blog.",
      title: "Scandal Spreads"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectAuthorityLaunderingJob.perform_now(investigation.id)

    investigation.reload
    assert investigation.authority_laundering.present?
    assert investigation.authority_laundering.key?("chains")
    assert investigation.authority_laundering.key?("laundering_score")
    assert investigation.authority_laundering.key?("circular_citations_found")
    assert investigation.authority_laundering.key?("summary")
  end

  test "creates pipeline step" do
    root = Article.create!(
      url: "https://aljob2.com/article", normalized_url: "https://aljob2.com/article",
      host: "aljob2.com", fetch_status: :fetched,
      body_text: "Content.", title: "Test"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectAuthorityLaunderingJob.perform_now(investigation.id)

    step = investigation.pipeline_steps.find_by(name: "detect_authority_laundering")
    assert_equal "completed", step.status
  end
end
