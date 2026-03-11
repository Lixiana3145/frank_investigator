require "test_helper"

class Analyzers::ClaimExtractorLlmTest < ActiveSupport::TestCase
  test "heuristic extraction still works without LLM" do
    article = Article.create!(
      url: "https://a.com/extractor-test", normalized_url: "https://a.com/extractor-test",
      host: "a.com", fetch_status: :fetched,
      title: "Congress passes major infrastructure bill worth $500 billion",
      body_text: "The United States Congress passed a major infrastructure bill today. " \
                 "The bill allocates $500 billion for roads, bridges, and broadband. " \
                 "President signed the bill into law at a ceremony. " \
                 "Economists estimate 2 million jobs will be created over five years. " \
                 "Opposition leaders called the spending excessive and irresponsible. " \
                 "Transportation secretary praised the bipartisan effort. " \
                 "The bill includes provisions for electric vehicle charging stations across the country."
    )

    results = Analyzers::ClaimExtractor.call(article)

    assert results.length >= 2
    assert results.any? { |r| r.role == :headline }
    assert results.any? { |r| r.role == :lead || r.role == :body }
  end

  test "deduplicates claims by fingerprint" do
    article = Article.create!(
      url: "https://a.com/dedup-test", normalized_url: "https://a.com/dedup-test",
      host: "a.com", fetch_status: :fetched,
      title: "Inflation rose to 8 percent in March according to official data",
      body_text: "Inflation rose to 8 percent in March according to official data from the bureau. " \
                 "The increase was driven by food and energy prices. " \
                 "Core inflation excluding food and energy was lower at 5.2 percent."
    )

    results = Analyzers::ClaimExtractor.call(article)
    fingerprints = results.map { |r| Analyzers::ClaimFingerprint.call(r.canonical_text) }
    assert_equal fingerprints.uniq.count, fingerprints.count
  end

  test "classifies checkability of each claim" do
    article = Article.create!(
      url: "https://a.com/check-test", normalized_url: "https://a.com/check-test",
      host: "a.com", fetch_status: :fetched,
      title: "I think the economy is doing terribly and everyone knows it",
      body_text: "The unemployment rate fell to 3.5 percent last month according to BLS data. " \
                 "This is terrible news for workers everywhere in my opinion."
    )

    results = Analyzers::ClaimExtractor.call(article)
    checkable_results = results.select { |r| r.checkability_status == :checkable }
    not_checkable_results = results.select { |r| r.checkability_status == :not_checkable }

    assert checkable_results.any? || not_checkable_results.any?, "Should classify at least some claims"
  end
end
