require "test_helper"

class Analyzers::EditorialRiskTest < ActiveSupport::TestCase
  setup do
    @previous_llm_client = Rails.application.config.x.frank_investigator.llm_client_class
    Rails.application.config.x.frank_investigator.llm_client_class = "Llm::FakeClient"
    Llm::FakeClient.next_result = nil
  end

  teardown do
    Rails.application.config.x.frank_investigator.llm_client_class = @previous_llm_client
    Llm::FakeClient.next_result = nil
  end

  test "caps confidence when all evidence comes from same editorial group" do
    # Create a media ownership group
    group = MediaOwnershipGroup.create!(
      name: "BigMediaCorp",
      owned_hosts: [ "news-a.bigmedia.com", "news-b.bigmedia.com" ],
      parent_company: "BigMediaCorp Inc"
    )

    root = Article.create!(url: "https://example.com/editorial-risk-1", normalized_url: "https://example.com/editorial-risk-1", host: "example.com", fetch_status: :fetched)
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)
    claim = Claim.create!(
      canonical_text: "The merger was approved by regulators last week.",
      canonical_fingerprint: "merger approved regulators editorial risk test",
      checkability_status: :checkable
    )
    ArticleClaim.create!(article: root, claim: claim, role: :body, surface_text: claim.canonical_text)

    # Two evidence articles from the same ownership group
    ev1 = Article.create!(
      url: "https://news-a.bigmedia.com/merger",
      normalized_url: "https://news-a.bigmedia.com/merger",
      host: "news-a.bigmedia.com",
      title: "Merger approved by regulators",
      body_text: "The merger was approved by regulators last week in a landmark decision that affects all sectors. Industry analysts said the approval was expected after months of review by the antitrust authority.",
      excerpt: "Merger approved by regulators.",
      fetch_status: :fetched, fetched_at: Time.current,
      source_kind: :news_article, authority_tier: :secondary, authority_score: 0.75,
      independence_group: "bigmedia"
    )
    ev2 = Article.create!(
      url: "https://news-b.bigmedia.com/merger",
      normalized_url: "https://news-b.bigmedia.com/merger",
      host: "news-b.bigmedia.com",
      title: "Regulators green-light the merger",
      body_text: "Regulators approved the merger last week as expected by market analysts and industry watchers. The decision was unanimous among the five commissioners who reviewed the application over several months.",
      excerpt: "Regulators green-light the merger.",
      fetch_status: :fetched, fetched_at: Time.current,
      source_kind: :news_article, authority_tier: :secondary, authority_score: 0.72,
      independence_group: "bigmedia"
    )
    ArticleClaim.create!(article: ev1, claim: claim, role: :supporting, surface_text: claim.canonical_text)
    ArticleClaim.create!(article: ev2, claim: claim, role: :supporting, surface_text: claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation: investigation, claim: claim)

    # Independence should be low due to single ownership cluster
    assert_operator result.independence_score, :<=, 0.3,
      "Independence should be low when all evidence is from one editorial group"
    # Confidence should be capped
    assert_operator result.confidence_score, :<=, 0.65,
      "Confidence should be capped when independence is very low"
  end

  test "does not cap confidence with diverse editorial sources" do
    root = Article.create!(url: "https://example.com/editorial-risk-2", normalized_url: "https://example.com/editorial-risk-2", host: "example.com", fetch_status: :fetched)
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)
    claim = Claim.create!(
      canonical_text: "The central bank raised interest rates by 0.5 percent.",
      canonical_fingerprint: "central bank raised rates 0.5 editorial risk diverse",
      checkability_status: :checkable
    )
    ArticleClaim.create!(article: root, claim: claim, role: :body, surface_text: claim.canonical_text)

    # Evidence from different, independent sources
    ev1 = Article.create!(
      url: "https://fed.gov/rates-decision",
      normalized_url: "https://fed.gov/rates-decision",
      host: "fed.gov",
      title: "Federal Reserve raises rates",
      body_text: "The central bank raised interest rates by 0.5 percent at its latest meeting. The decision was widely expected by economists and marks the third consecutive rate increase this year as the Fed battles persistent inflation.",
      excerpt: "Federal Reserve raises rates.",
      fetch_status: :fetched, fetched_at: Time.current,
      source_kind: :government_record, authority_tier: :primary, authority_score: 0.98,
      independence_group: "fed.gov"
    )
    ev2 = Article.create!(
      url: "https://reuters.com/rates",
      normalized_url: "https://reuters.com/rates",
      host: "reuters.com",
      title: "Reuters: Central bank rate hike",
      body_text: "The central bank raised interest rates by 0.5 percent, as widely expected. Market analysts noted the move was priced in by bond markets and equity futures showed little reaction to the announcement.",
      excerpt: "Central bank rate hike.",
      fetch_status: :fetched, fetched_at: Time.current,
      source_kind: :news_article, authority_tier: :secondary, authority_score: 0.8,
      independence_group: "reuters.com"
    )
    ArticleClaim.create!(article: ev1, claim: claim, role: :supporting, surface_text: claim.canonical_text)
    ArticleClaim.create!(article: ev2, claim: claim, role: :supporting, surface_text: claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation: investigation, claim: claim)
    assert_operator result.independence_score, :>, 0.05,
      "Independence should be positive with diverse sources"
  end

  test "independence analyzer detects single ownership cluster penalty" do
    group = MediaOwnershipGroup.find_or_create_by!(name: "TestMediaGroup") do |g|
      g.owned_hosts = [ "outlet-a.com", "outlet-b.com" ]
    end

    articles = [
      Article.create!(url: "https://outlet-a.com/a1", normalized_url: "https://outlet-a.com/a1", host: "outlet-a.com",
        body_text: "Some long article body that is meaningful enough to analyze properly for this test case. This content discusses important policy developments that have wide-ranging implications across multiple sectors.",
        fetch_status: :fetched, independence_group: "testmedia"),
      Article.create!(url: "https://outlet-b.com/a2", normalized_url: "https://outlet-b.com/a2", host: "outlet-b.com",
        body_text: "Another distinct article body that covers a completely different topic to avoid syndication detection. The reporter interviewed several experts who provided unique perspectives on the matter at hand.",
        fetch_status: :fetched, independence_group: "testmedia")
    ]

    result = Analyzers::IndependenceAnalyzer.call(articles: articles)
    assert result.penalties.any? { |p| p[:type] == "single_ownership_cluster" },
      "Should detect single ownership cluster penalty"
    assert_operator result.independence_score, :<, 0.3
  end

  test "independence analyzer passes with truly independent sources" do
    articles = [
      Article.create!(url: "https://independent-a.com/a1", normalized_url: "https://independent-a.com/a1", host: "independent-a.com",
        body_text: "First independent source with unique editorial content covering the policy change. Local reporters confirmed the details through interviews with government officials and community members affected by it.",
        fetch_status: :fetched, independence_group: "independent-a"),
      Article.create!(url: "https://independent-b.org/a2", normalized_url: "https://independent-b.org/a2", host: "independent-b.org",
        body_text: "Second independent source reporting on a totally separate aspect of the story. Their investigation revealed previously unknown connections between the stakeholders and the regulatory process.",
        fetch_status: :fetched, independence_group: "independent-b"),
      Article.create!(url: "https://independent-c.net/a3", normalized_url: "https://independent-c.net/a3", host: "independent-c.net",
        body_text: "Third independent outlet with its own unique coverage and editorial perspective. Their analysis focused on the long-term economic impacts and consulted leading academic researchers in the field.",
        fetch_status: :fetched, independence_group: "independent-c")
    ]

    result = Analyzers::IndependenceAnalyzer.call(articles: articles)
    assert_equal 3, result.independent_groups_count
    assert result.penalties.none? { |p| p[:type] == "single_ownership_cluster" }
    assert_operator result.independence_score, :>=, 0.5
  end
end
