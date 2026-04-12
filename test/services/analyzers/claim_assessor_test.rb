require "test_helper"

class Analyzers::ClaimAssessorTest < ActiveSupport::TestCase
  FakeEntry = Struct.new(:authority_tier, :relevance_score, :independence_group,
    :stance, :article, :authority_score, :headline_divergence, :source_kind,
    :source_role,
    keyword_init: true)
  FakeArticle = Struct.new(:published_at, :fetched_at, keyword_init: true)

  setup do
    @previous_llm_client = Rails.application.config.x.frank_investigator.llm_client_class
    Rails.application.config.x.frank_investigator.llm_client_class = "Llm::FakeClient"
    Llm::FakeClient.next_result = nil
  end

  teardown do
    Rails.application.config.x.frank_investigator.llm_client_class = @previous_llm_client
    Llm::FakeClient.next_result = nil
  end

  test "marks a claim supported when weighted primary evidence is strong" do
    root = Article.create!(url: "https://example.com/news", normalized_url: "https://example.com/news", host: "example.com", fetch_status: :fetched)
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)
    claim = Claim.create!(canonical_text: "The budget report confirms a 4 percent tax reduction in 2026.", canonical_fingerprint: "budget report confirms 4 percent tax reduction 2026", checkability_status: :checkable)
    ArticleClaim.create!(article: root, claim:, role: :body, surface_text: claim.canonical_text)

    evidence_article = Article.create!(
      url: "https://www.sec.gov/reports/budget-filing",
      normalized_url: "https://www.sec.gov/reports/budget-filing",
      host: "www.sec.gov",
      title: "Budget report confirms a 4 percent tax reduction in 2026",
      body_text: "The budget report confirms a 4 percent tax reduction in 2026.",
      excerpt: "Budget report confirms a 4 percent tax reduction in 2026.",
      fetch_status: :fetched,
      fetched_at: Time.current,
      source_kind: :government_record,
      authority_tier: :primary,
      authority_score: 0.98,
      independence_group: "sec.gov"
    )
    ArticleClaim.create!(article: evidence_article, claim:, role: :supporting, surface_text: claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation:, claim:)

    assert_equal :supported, result.verdict
    assert_operator result.authority_score, :>=, 0.9
    assert_operator result.confidence_score, :>=, 0.5
  end

  test "marks a claim mixed when support and dispute are both strong" do
    root = Article.create!(url: "https://example.com/news-2", normalized_url: "https://example.com/news-2", host: "example.com", fetch_status: :fetched)
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)
    claim = Claim.create!(canonical_text: "The mayor approved the measure yesterday.", canonical_fingerprint: "mayor approved measure yesterday", checkability_status: :checkable)

    supportive = Article.create!(
      url: "https://city.gov/press/measure",
      normalized_url: "https://city.gov/press/measure",
      host: "city.gov",
      title: "The mayor approved the measure yesterday",
      body_text: "The mayor approved the measure yesterday.",
      excerpt: "The mayor approved the measure yesterday.",
      fetch_status: :fetched,
      fetched_at: Time.current,
      source_kind: :government_record,
      authority_tier: :primary,
      authority_score: 0.96,
      independence_group: "city.gov"
    )
    disputing = Article.create!(
      url: "https://news.example.net/check",
      normalized_url: "https://news.example.net/check",
      host: "news.example.net",
      title: "No evidence the mayor approved the measure yesterday",
      body_text: "There is no evidence the mayor approved the measure yesterday.",
      excerpt: "No evidence the mayor approved the measure yesterday.",
      fetch_status: :fetched,
      fetched_at: Time.current,
      source_kind: :news_article,
      source_role: :news_reporting,
      authority_tier: :secondary,
      authority_score: 0.64,
      independence_group: "example.net"
    )

    ArticleClaim.create!(article: supportive, claim:, role: :supporting, surface_text: claim.canonical_text)
    ArticleClaim.create!(article: disputing, claim:, role: :supporting, surface_text: claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation:, claim:)

    assert_equal :mixed, result.verdict
    assert_operator result.conflict_score, :>, 0.5
  end

  test "diverse independent sources produce higher sufficiency than single-outlet" do
    assessor = Analyzers::ClaimAssessor.new(
      investigation: Investigation.new,
      claim: Claim.new(canonical_text: "test", checkability_status: :checkable)
    )

    now = Time.current
    single_outlet_entry = FakeEntry.new(
      authority_tier: "secondary", relevance_score: 0.6, independence_group: "uol.com.br",
      stance: :supports, article: FakeArticle.new(published_at: now, fetched_at: now),
      authority_score: 0.5, headline_divergence: 0.0, source_kind: "news"
    )

    diverse_entries = [
      FakeEntry.new(
        authority_tier: "secondary", relevance_score: 0.6, independence_group: "uol.com.br",
        stance: :supports, article: FakeArticle.new(published_at: now, fetched_at: now),
        authority_score: 0.5, headline_divergence: 0.0, source_kind: "news"
      ),
      FakeEntry.new(
        authority_tier: "secondary", relevance_score: 0.5, independence_group: "reuters.com",
        stance: :supports, article: FakeArticle.new(published_at: now, fetched_at: now),
        authority_score: 0.6, headline_divergence: 0.0, source_kind: "news"
      ),
      FakeEntry.new(
        authority_tier: "secondary", relevance_score: 0.5, independence_group: "bloomberg.com",
        stance: :supports, article: FakeArticle.new(published_at: now, fetched_at: now),
        authority_score: 0.6, headline_divergence: 0.0, source_kind: "news"
      )
    ]

    single_sufficiency = assessor.send(:normalized_sufficiency_score, [ single_outlet_entry ])
    diverse_sufficiency = assessor.send(:normalized_sufficiency_score, diverse_entries)

    assert_operator diverse_sufficiency, :>, single_sufficiency,
      "Diverse sources (#{diverse_sufficiency}) should have higher sufficiency than single outlet (#{single_sufficiency})"
    assert_operator diverse_sufficiency, :>=, 0.35,
      "Diverse sources should cross the 0.35 sufficiency threshold"
  end

  test "single-outlet evidence stays below sufficiency threshold" do
    assessor = Analyzers::ClaimAssessor.new(
      investigation: Investigation.new,
      claim: Claim.new(canonical_text: "test", checkability_status: :checkable)
    )

    now = Time.current
    single_entries = [
      FakeEntry.new(
        authority_tier: "secondary", relevance_score: 0.6, independence_group: "uol.com.br",
        stance: :supports, article: FakeArticle.new(published_at: now, fetched_at: now),
        authority_score: 0.5, headline_divergence: 0.0, source_kind: "news"
      ),
      FakeEntry.new(
        authority_tier: "secondary", relevance_score: 0.5, independence_group: "uol.com.br",
        stance: :supports, article: FakeArticle.new(published_at: now, fetched_at: now),
        authority_score: 0.5, headline_divergence: 0.0, source_kind: "news"
      )
    ]

    sufficiency = assessor.send(:normalized_sufficiency_score, single_entries)
    assert_kind_of Numeric, sufficiency
  end

  test "secondary opinion and blog evidence cannot sustain evaluative performance claims" do
    root = Article.create!(
      url: "https://example.com/performance",
      normalized_url: "https://example.com/performance",
      host: "example.com",
      fetch_status: :fetched
    )
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)
    claim = Claim.create!(
      canonical_text: "The minister was an effective leader during the crisis.",
      canonical_fingerprint: "effective-leader-crisis",
      checkability_status: :checkable
    )
    ArticleClaim.create!(article: root, claim:, role: :body, surface_text: claim.canonical_text)

    opinion_article = Article.create!(
      url: "https://newspaper.example.com/colunas/effective-leader",
      normalized_url: "https://newspaper.example.com/colunas/effective-leader",
      host: "newspaper.example.com",
      title: "Why the minister was an effective leader",
      body_text: "In this opinion column, the author argues the minister was an effective leader during the crisis.",
      excerpt: "Opinion column about leadership.",
      fetch_status: :fetched,
      fetched_at: Time.current,
      source_kind: :news_article,
      source_role: :opinion_column,
      authority_tier: :secondary,
      authority_score: 0.72,
      independence_group: "newspaper.example.com"
    )
    blog_article = Article.create!(
      url: "https://blogexample.com/2026/04/leadership/",
      normalized_url: "https://blogexample.com/2026/04/leadership/",
      host: "blogexample.com",
      title: "The minister handled the crisis well",
      body_text: "A blog post repeating that the minister handled the crisis well and deserved praise.",
      excerpt: "Blog commentary about leadership.",
      fetch_status: :fetched,
      fetched_at: Time.current,
      source_kind: :news_article,
      source_role: :blog_amplification,
      authority_tier: :secondary,
      authority_score: 0.58,
      independence_group: "blogexample.com"
    )

    ArticleClaim.create!(article: opinion_article, claim:, role: :supporting, surface_text: claim.canonical_text)
    ArticleClaim.create!(article: blog_article, claim:, role: :supporting, surface_text: claim.canonical_text)

    result = Analyzers::ClaimAssessor.call(investigation:, claim:)

    assert_equal :needs_more_evidence, result.verdict
    assert_operator result.confidence_score, :<=, 0.35
  end
end
