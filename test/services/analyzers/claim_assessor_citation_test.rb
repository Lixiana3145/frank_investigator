require "test_helper"

class Analyzers::ClaimAssessorCitationTest < ActiveSupport::TestCase
  setup do
    @previous_llm = Rails.application.config.x.frank_investigator.llm_client_class
    Rails.application.config.x.frank_investigator.llm_client_class = "Llm::FakeClient"
    Llm::FakeClient.next_result = nil
  end

  teardown do
    Rails.application.config.x.frank_investigator.llm_client_class = @previous_llm
    Llm::FakeClient.next_result = nil
  end

  test "reason summary cites primary sources by name" do
    root = Article.create!(url: "https://a.com/cite1", normalized_url: "https://a.com/cite1", host: "a.com", fetch_status: :fetched)
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)
    claim = Claim.create!(canonical_text: "Congress passed the infrastructure bill with bipartisan support", canonical_fingerprint: "cite_congress", checkability_status: :checkable)
    ArticleClaim.create!(article: root, claim:, role: :body, surface_text: claim.canonical_text)

    gov = Article.create!(
      url: "https://congress.gov/bill/test", normalized_url: "https://congress.gov/bill/test",
      host: "congress.gov", title: "H.R.3684 Infrastructure Act",
      body_text: "Congress passed the infrastructure bill with bipartisan support. The bill received 228 votes in favor.",
      excerpt: "Bill passed with bipartisan support", fetch_status: :fetched, fetched_at: Time.current,
      source_kind: :government_record, authority_tier: :primary, authority_score: 0.95,
      independence_group: "congress.gov"
    )
    ArticleClaim.create!(article: gov, claim:, role: :supporting, surface_text: claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation:, claim:)

    assert_includes result.reason_summary, "H.R.3684 Infrastructure Act"
    assert_includes result.reason_summary, "Primary source"
  end

  test "missing evidence summary identifies specific gaps" do
    root = Article.create!(url: "https://a.com/gaps1", normalized_url: "https://a.com/gaps1", host: "a.com", fetch_status: :fetched)
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)
    claim = Claim.create!(canonical_text: "The inflation rate reached 5 percent in January confirmed by data", canonical_fingerprint: "cite_gaps", checkability_status: :checkable)
    ArticleClaim.create!(article: root, claim:, role: :body, surface_text: claim.canonical_text)

    # Single weak source
    news = Article.create!(
      url: "https://blog.example.com/inflation", normalized_url: "https://blog.example.com/inflation",
      host: "blog.example.com", title: "Inflation analysis blog post",
      body_text: "The inflation rate reached 5 percent in January according to various sources.",
      fetch_status: :fetched, fetched_at: Time.current,
      source_kind: :news_article, authority_tier: :secondary, authority_score: 0.4,
      independence_group: "blog.example.com"
    )
    ArticleClaim.create!(article: news, claim:, role: :supporting, surface_text: claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation:, claim:)

    assert_includes result.missing_evidence_summary, "primary"
    assert_includes result.missing_evidence_summary, "independent"
  end

  test "identifies when no contradiction checks exist" do
    root = Article.create!(url: "https://a.com/nocon", normalized_url: "https://a.com/nocon", host: "a.com", fetch_status: :fetched)
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)
    claim = Claim.create!(canonical_text: "Company reported record profits for the quarter as confirmed", canonical_fingerprint: "cite_nocon", checkability_status: :checkable)
    ArticleClaim.create!(article: root, claim:, role: :body, surface_text: claim.canonical_text)

    # Multiple supporting but no disputing sources
    3.times do |i|
      src = Article.create!(
        url: "https://src#{i}.com/profits", normalized_url: "https://src#{i}.com/profits",
        host: "src#{i}.com", title: "Profit report #{i}",
        body_text: "Company reported record profits for the quarter. Revenue exceeded expectations.",
        fetch_status: :fetched, fetched_at: Time.current,
        source_kind: :news_article, authority_tier: :secondary, authority_score: 0.5,
        independence_group: "src#{i}.com"
      )
      ArticleClaim.create!(article: src, claim:, role: :supporting, surface_text: claim.canonical_text)
    end

    result = Analyzers::ClaimAssessor.call(investigation:, claim:)

    assert_includes result.missing_evidence_summary, "contradiction"
  end
end
