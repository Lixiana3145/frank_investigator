require "test_helper"

class Analyzers::ActiveEvidenceRetrieverTest < ActiveSupport::TestCase
  setup do
    @root = Article.create!(
      url: "https://news.com/aer1", normalized_url: "https://news.com/aer1",
      host: "news.com", fetch_status: :fetched
    )
    @investigation = Investigation.create!(
      submitted_url: @root.url, normalized_url: @root.normalized_url, root_article: @root
    )
    @claim = Claim.create!(
      canonical_text: "Congress passed bill H.R.1234 to fund infrastructure",
      canonical_fingerprint: "aer_congress_test",
      checkability_status: :checkable
    )
    ArticleClaim.create!(article: @root, claim: @claim, role: :body, surface_text: @claim.canonical_text)
    # Use fake fetcher
    @previous_fetcher = Rails.application.config.x.frank_investigator.fetcher_class
    Rails.application.config.x.frank_investigator.fetcher_class = "Fetchers::FakeFetcher"
  end

  teardown do
    Rails.application.config.x.frank_investigator.fetcher_class = @previous_fetcher
    Fetchers::FakeFetcher.clear
  end

  test "generates search URLs for authority types" do
    Fetchers::FakeFetcher.register(
      /congress\.gov/,
      "<html><head><title>Search Results</title></head><body><p>H.R.1234 Infrastructure Act passed by Congress</p></body></html>",
      "Congress.gov Search"
    )

    results = Analyzers::ActiveEvidenceRetriever.call(investigation: @investigation, claim: @claim)

    assert results.is_a?(Array)
  end

  test "skips when evidence already exists from suggested hosts" do
    Article.create!(
      url: "https://congress.gov/existing", normalized_url: "https://congress.gov/existing",
      host: "congress.gov", fetch_status: :fetched, body_text: "Existing evidence"
    ).tap do |article|
      ArticleClaim.create!(article:, claim: @claim, role: :linked_source, surface_text: @claim.canonical_text)
    end

    results = Analyzers::ActiveEvidenceRetriever.call(investigation: @investigation, claim: @claim)
    assert_equal 0, results.count { |a| a.host == "congress.gov" }
  end

  test "respects MAX_FETCHES_PER_CLAIM limit" do
    claim = Claim.create!(
      canonical_text: "The CPI inflation rate rose 3 percent according to BLS statistics and the FRED index showed GDP growth",
      canonical_fingerprint: "aer_multi_query",
      checkability_status: :checkable
    )
    ArticleClaim.create!(article: @root, claim:, role: :body, surface_text: claim.canonical_text)

    Fetchers::FakeFetcher.register(
      /./,
      "<html><head><title>Result</title></head><body><p>Some content</p></body></html>",
      "Search Result"
    )

    results = Analyzers::ActiveEvidenceRetriever.call(investigation: @investigation, claim:)
    assert results.length <= Analyzers::ActiveEvidenceRetriever::MAX_FETCHES_PER_CLAIM
  end
end
