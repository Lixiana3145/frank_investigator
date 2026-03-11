require "test_helper"

class Analyzers::ClaimPriorFactcheckTest < ActiveSupport::TestCase
  setup do
    @previous_llm_client = Rails.application.config.x.frank_investigator.llm_client_class
    Rails.application.config.x.frank_investigator.llm_client_class = "Llm::FakeClient"
    Llm::FakeClient.next_result = nil
  end

  teardown do
    Rails.application.config.x.frank_investigator.llm_client_class = @previous_llm_client
    Llm::FakeClient.next_result = nil
  end

  test "reuses exact prior assessment from another investigation" do
    root1 = Article.create!(url: "https://example.com/prior-fc-1", normalized_url: "https://example.com/prior-fc-1", host: "example.com", fetch_status: :fetched)
    inv1 = Investigation.create!(submitted_url: root1.url, normalized_url: root1.normalized_url, root_article: root1)
    claim = Claim.create!(canonical_text: "The GDP grew 3% in 2025.", canonical_fingerprint: "gdp grew 3 percent 2025 prior fc", checkability_status: :checkable)

    # Create a prior completed assessment
    ClaimAssessment.create!(
      investigation: inv1, claim: claim,
      verdict: :supported, confidence_score: 0.85, checkability_status: :checkable,
      reason_summary: "Supported by government data.", authority_score: 0.9,
      independence_score: 0.7, timeliness_score: 0.8, conflict_score: 0.1
    )

    # New investigation for the same claim
    root2 = Article.create!(url: "https://example.com/prior-fc-2", normalized_url: "https://example.com/prior-fc-2", host: "example.com", fetch_status: :fetched)
    inv2 = Investigation.create!(submitted_url: root2.url, normalized_url: root2.normalized_url, root_article: root2)
    ArticleClaim.create!(article: root2, claim: claim, role: :body, surface_text: claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation: inv2, claim: claim)
    assert_equal :supported, result.verdict
    assert_includes result.reason_summary, "exact match"
    assert_in_delta 0.80, result.confidence_score, 0.01
  end

  test "reuses similar claim assessment via similarity matching" do
    root1 = Article.create!(url: "https://example.com/prior-fc-3", normalized_url: "https://example.com/prior-fc-3", host: "example.com", fetch_status: :fetched)
    inv1 = Investigation.create!(submitted_url: root1.url, normalized_url: root1.normalized_url, root_article: root1)

    original_claim = Claim.create!(
      canonical_text: "Brazil GDP grew 3.1% in the first quarter of 2025 according to IBGE official data",
      canonical_fingerprint: "brazil gdp grew 3.1 q1 2025 ibge prior",
      checkability_status: :checkable
    )
    ClaimAssessment.create!(
      investigation: inv1, claim: original_claim,
      verdict: :supported, confidence_score: 0.82, checkability_status: :checkable,
      reason_summary: "Confirmed by IBGE statistics.", authority_score: 0.95,
      independence_score: 0.6, timeliness_score: 0.85, conflict_score: 0.05
    )

    # New investigation with a very similar (but not identical) claim
    root2 = Article.create!(url: "https://example.com/prior-fc-4", normalized_url: "https://example.com/prior-fc-4", host: "example.com", fetch_status: :fetched)
    inv2 = Investigation.create!(submitted_url: root2.url, normalized_url: root2.normalized_url, root_article: root2)

    similar_claim = Claim.create!(
      canonical_text: "Brazil GDP grew 3.1% in the first quarter of 2025 per IBGE official statistics",
      canonical_fingerprint: "brazil gdp grew 3.1 q1 2025 ibge statistics similar",
      checkability_status: :checkable
    )
    ArticleClaim.create!(article: root2, claim: similar_claim, role: :body, surface_text: similar_claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation: inv2, claim: similar_claim)
    assert_equal :supported, result.verdict
    assert_includes result.reason_summary, "similar claim match"
  end

  test "does not reuse dissimilar claims" do
    root1 = Article.create!(url: "https://example.com/prior-fc-5", normalized_url: "https://example.com/prior-fc-5", host: "example.com", fetch_status: :fetched)
    inv1 = Investigation.create!(submitted_url: root1.url, normalized_url: root1.normalized_url, root_article: root1)

    unrelated_claim = Claim.create!(
      canonical_text: "The stock market reached an all-time high in December 2025.",
      canonical_fingerprint: "stock market all time high dec 2025 prior",
      checkability_status: :checkable
    )
    ClaimAssessment.create!(
      investigation: inv1, claim: unrelated_claim,
      verdict: :supported, confidence_score: 0.9, checkability_status: :checkable,
      reason_summary: "Market data confirms.", authority_score: 0.9
    )

    # Completely different claim
    root2 = Article.create!(url: "https://example.com/prior-fc-6", normalized_url: "https://example.com/prior-fc-6", host: "example.com", fetch_status: :fetched)
    inv2 = Investigation.create!(submitted_url: root2.url, normalized_url: root2.normalized_url, root_article: root2)

    new_claim = Claim.create!(
      canonical_text: "Unemployment rose to 8% in Brazil during March 2026.",
      canonical_fingerprint: "unemployment rose 8 percent brazil march 2026 prior",
      checkability_status: :checkable
    )
    ArticleClaim.create!(article: root2, claim: new_claim, role: :body, surface_text: new_claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation: inv2, claim: new_claim)
    # Should NOT reuse the unrelated assessment
    refute_includes result.reason_summary.to_s, "Reused from a prior investigation"
  end

  test "does not reuse low-confidence prior assessments" do
    root1 = Article.create!(url: "https://example.com/prior-fc-7", normalized_url: "https://example.com/prior-fc-7", host: "example.com", fetch_status: :fetched)
    inv1 = Investigation.create!(submitted_url: root1.url, normalized_url: root1.normalized_url, root_article: root1)

    claim = Claim.create!(
      canonical_text: "The new policy reduced emissions by 20%.",
      canonical_fingerprint: "new policy reduced emissions 20 percent prior",
      checkability_status: :checkable
    )
    ClaimAssessment.create!(
      investigation: inv1, claim: claim,
      verdict: :needs_more_evidence, confidence_score: 0.30, checkability_status: :checkable,
      reason_summary: "Insufficient evidence.", authority_score: 0.2
    )

    root2 = Article.create!(url: "https://example.com/prior-fc-8", normalized_url: "https://example.com/prior-fc-8", host: "example.com", fetch_status: :fetched)
    inv2 = Investigation.create!(submitted_url: root2.url, normalized_url: root2.normalized_url, root_article: root2)
    ArticleClaim.create!(article: root2, claim: claim, role: :body, surface_text: claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation: inv2, claim: claim)
    # Should NOT reuse because confidence < 0.4
    refute_includes result.reason_summary.to_s, "Reused from a prior investigation"
  end

  test "applies confidence penalty when reusing" do
    root1 = Article.create!(url: "https://example.com/prior-fc-9", normalized_url: "https://example.com/prior-fc-9", host: "example.com", fetch_status: :fetched)
    inv1 = Investigation.create!(submitted_url: root1.url, normalized_url: root1.normalized_url, root_article: root1)

    claim = Claim.create!(
      canonical_text: "Inflation was 4.5% in February 2026.",
      canonical_fingerprint: "inflation 4.5 percent february 2026 prior penalty",
      checkability_status: :checkable
    )
    ClaimAssessment.create!(
      investigation: inv1, claim: claim,
      verdict: :supported, confidence_score: 0.75, checkability_status: :checkable,
      reason_summary: "Confirmed by CPI data.", authority_score: 0.85
    )

    root2 = Article.create!(url: "https://example.com/prior-fc-10", normalized_url: "https://example.com/prior-fc-10", host: "example.com", fetch_status: :fetched)
    inv2 = Investigation.create!(submitted_url: root2.url, normalized_url: root2.normalized_url, root_article: root2)
    ArticleClaim.create!(article: root2, claim: claim, role: :body, surface_text: claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation: inv2, claim: claim)
    assert_equal :supported, result.verdict
    # 0.75 - 0.05 = 0.70
    assert_in_delta 0.70, result.confidence_score, 0.01
  end
end
