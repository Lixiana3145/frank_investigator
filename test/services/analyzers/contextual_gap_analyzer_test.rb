require "test_helper"

class Analyzers::ContextualGapAnalyzerTest < ActiveSupport::TestCase
  setup do
    @root = Article.create!(
      url: "https://gaptest.com/article", normalized_url: "https://gaptest.com/article",
      host: "gaptest.com", fetch_status: :fetched,
      body_text: "This article argues that higher fuel prices benefit clean energy innovation, citing US studies.",
      title: "Why Expensive Fuel Is Good"
    )
    @investigation = Investigation.create!(
      submitted_url: @root.url, normalized_url: @root.normalized_url,
      root_article: @root, status: :processing
    )
  end

  test "identifies gaps for article with supported claims" do
    root = Article.create!(
      url: "https://gaptest.com.br/artigo", normalized_url: "https://gaptest.com.br/artigo",
      host: "gaptest.com.br", fetch_status: :fetched,
      body_text: "Este artigo argumenta que preços altos de combustível beneficiam inovação em energia limpa, citando estudos americanos de 2002.",
      title: "Por que combustível caro é bom"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )
    claim = Claim.create!(canonical_text: "Higher prices drive innovation", canonical_fingerprint: "gap_#{SecureRandom.hex(4)}", checkability_status: :checkable)
    ClaimAssessment.create!(investigation:, claim:, verdict: :supported, confidence_score: 0.7, checkability_status: :checkable)

    result = Analyzers::ContextualGapAnalyzer.call(investigation:)

    assert_kind_of Analyzers::ContextualGapAnalyzer::Result, result
    assert_kind_of Array, result.gaps
    assert_includes 0.0..1.0, result.completeness_score
    assert result.summary.present?
  end

  test "detects one-sided evidence when all claims supported and none disputed" do
    claim1 = Claim.create!(canonical_text: "Claim A", canonical_fingerprint: "gap2_#{SecureRandom.hex(4)}", checkability_status: :checkable)
    claim2 = Claim.create!(canonical_text: "Claim B", canonical_fingerprint: "gap3_#{SecureRandom.hex(4)}", checkability_status: :checkable)
    ClaimAssessment.create!(investigation: @investigation, claim: claim1, verdict: :supported, confidence_score: 0.8, checkability_status: :checkable)
    ClaimAssessment.create!(investigation: @investigation, claim: claim2, verdict: :supported, confidence_score: 0.7, checkability_status: :checkable)

    result = Analyzers::ContextualGapAnalyzer.call(investigation: @investigation)

    assert result.gaps.any? { |g| g.question.present? }
  end

  test "returns empty result when no assessed claims" do
    result = Analyzers::ContextualGapAnalyzer.call(investigation: @investigation)

    assert_equal [], result.gaps
    assert_equal 1.0, result.completeness_score
  end

  test "returns empty result when article has no body text" do
    @root.update!(body_text: nil)
    result = Analyzers::ContextualGapAnalyzer.call(investigation: @investigation)

    assert_equal [], result.gaps
    assert_equal 1.0, result.completeness_score
  end

  test "gap struct has expected fields" do
    claim = Claim.create!(canonical_text: "Test claim", canonical_fingerprint: "gap4_#{SecureRandom.hex(4)}", checkability_status: :checkable)
    ClaimAssessment.create!(investigation: @investigation, claim:, verdict: :supported, confidence_score: 0.8, checkability_status: :checkable)

    result = Analyzers::ContextualGapAnalyzer.call(investigation: @investigation)

    result.gaps.each do |gap|
      assert_respond_to gap, :question
      assert_respond_to gap, :relevance
      assert_respond_to gap, :search_results
      assert_kind_of Array, gap.search_results
    end
  end
end
