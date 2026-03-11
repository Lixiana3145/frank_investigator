require "test_helper"

class Analyzers::EvidenceRelationshipAnalyzerEnhancedTest < ActiveSupport::TestCase
  test "detects Brazilian Portuguese negation patterns" do
    claim = Claim.create!(canonical_text: "O governo confirmou o investimento de R$ 50 bilhões", canonical_fingerprint: "era_br_neg", checkability_status: :checkable)
    article = Article.create!(
      url: "https://a.com/era_br1", normalized_url: "https://a.com/era_br1", host: "a.com",
      title: "Desmentido sobre investimento",
      body_text: "Não é verdade que o governo confirmou o investimento de R$ 50 bilhões. O anúncio foi apenas uma proposta preliminar sem confirmação oficial.",
      fetch_status: :fetched
    )

    result = Analyzers::EvidenceRelationshipAnalyzer.call(claim:, article:)
    assert_equal :disputes, result.stance
  end

  test "detects English refutation patterns" do
    claim = Claim.create!(canonical_text: "The vaccine causes serious side effects in most patients", canonical_fingerprint: "era_en_refute", checkability_status: :checkable)
    article = Article.create!(
      url: "https://a.com/era_en1", normalized_url: "https://a.com/era_en1", host: "a.com",
      title: "Vaccine safety study",
      body_text: "The study refutes claims that the vaccine causes serious side effects. Clinical trials showed the vaccine is safe with only mild side effects in a small percentage of patients.",
      fetch_status: :fetched
    )

    result = Analyzers::EvidenceRelationshipAnalyzer.call(claim:, article:)
    assert_equal :disputes, result.stance
  end

  test "returns reasoning when available" do
    claim = Claim.create!(canonical_text: "Something about facts", canonical_fingerprint: "era_reason", checkability_status: :checkable)
    article = Article.create!(
      url: "https://a.com/era_r1", normalized_url: "https://a.com/era_r1", host: "a.com",
      title: "Related topic",
      body_text: "Something about facts confirmed by multiple independent researchers and government agencies.",
      fetch_status: :fetched
    )

    result = Analyzers::EvidenceRelationshipAnalyzer.call(claim:, article:)
    # Without LLM, reasoning should be nil
    assert result.respond_to?(:reasoning)
  end

  test "without evidence missing keyword returns without failure" do
    claim = Claim.create!(canonical_text: "The budget was approved for fiscal year 2026", canonical_fingerprint: "era_missing", checkability_status: :checkable)
    article = Article.create!(
      url: "https://a.com/era_unrelated", normalized_url: "https://a.com/era_unrelated", host: "a.com",
      title: "Recipe for chocolate cake",
      body_text: "Mix flour, sugar, and cocoa powder together in a bowl. Add eggs and milk.",
      fetch_status: :fetched
    )

    result = Analyzers::EvidenceRelationshipAnalyzer.call(claim:, article:)
    assert_equal :contextualizes, result.stance
    assert_operator result.relevance_score, :<=, 0.05, "Unrelated article should have near-zero relevance"
  end
end
