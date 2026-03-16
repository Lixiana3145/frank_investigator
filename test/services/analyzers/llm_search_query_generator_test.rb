require "test_helper"

class Analyzers::LlmSearchQueryGeneratorTest < ActiveSupport::TestCase
  setup do
    @claim = Claim.create!(
      canonical_text: "Petrobras elevou o preço do diesel em 5% para distribuidoras",
      canonical_fingerprint: "search_gen_test_#{SecureRandom.hex(4)}",
      checkability_status: :checkable
    )
    @root = Article.create!(
      url: "https://uol.com.br/news/article-1", normalized_url: "https://uol.com.br/news/article-1",
      host: "uol.com.br", fetch_status: :fetched
    )
    @investigation = Investigation.create!(
      submitted_url: @root.url, normalized_url: @root.normalized_url, root_article: @root
    )
    # Save and clear env to force LLM unavailability
    @original_api_key = ENV["OPENROUTER_API_KEY"]
    ENV.delete("OPENROUTER_API_KEY")
  end

  teardown do
    ENV["OPENROUTER_API_KEY"] = @original_api_key if @original_api_key
  end

  test "returns fallback queries when LLM is not available" do
    result = Analyzers::LlmSearchQueryGenerator.call(
      claim: @claim,
      root_article_host: "uol.com.br",
      investigation: @investigation
    )

    assert_kind_of Array, result
    assert result.any?
    assert result.first.is_a?(String)
    assert_equal [ @claim.canonical_text.truncate(80) ], result
  end

  test "returns fallback when investigation is nil" do
    result = Analyzers::LlmSearchQueryGenerator.call(
      claim: @claim,
      root_article_host: "uol.com.br",
      investigation: nil
    )

    assert_kind_of Array, result
    assert result.any?
  end

  test "fallback query is claim text truncated to 80 chars" do
    long_claim = Claim.create!(
      canonical_text: "A" * 200,
      canonical_fingerprint: "long_claim_test_#{SecureRandom.hex(4)}",
      checkability_status: :checkable
    )

    result = Analyzers::LlmSearchQueryGenerator.call(
      claim: long_claim,
      root_article_host: "example.com",
      investigation: nil
    )

    assert_equal 1, result.size
    assert result.first.length <= 80
  end
end
