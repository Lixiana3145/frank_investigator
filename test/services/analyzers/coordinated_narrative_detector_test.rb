require "test_helper"

class Analyzers::CoordinatedNarrativeDetectorTest < ActiveSupport::TestCase
  setup do
    @root = Article.create!(
      url: "https://coordtest.com/article", normalized_url: "https://coordtest.com/article",
      host: "coordtest.com", fetch_status: :fetched,
      body_text: "GloboNews apologized for a PowerPoint that linked Lula to the Banco Master scandal. " \
                 "The graphic recalled Dallagnol's Lava Jato chart. Critics say Globo tried to criminalize the government.",
      title: "Globo pede desculpas por PowerPoint"
    )
    @investigation = Investigation.create!(
      submitted_url: @root.url, normalized_url: @root.normalized_url,
      root_article: @root, status: :processing
    )
  end

  test "returns valid result for article with body text" do
    claim = Claim.create!(canonical_text: "Globo apologized", canonical_fingerprint: "cn_#{SecureRandom.hex(4)}", checkability_status: :checkable)
    ClaimAssessment.create!(investigation: @investigation, claim:, verdict: :supported, confidence_score: 0.8, checkability_status: :checkable)

    result = Analyzers::CoordinatedNarrativeDetector.call(investigation: @investigation)

    assert_kind_of Analyzers::CoordinatedNarrativeDetector::Result, result
    assert_includes 0.0..1.0, result.coordination_score
    assert result.pattern_summary.present?
    assert_kind_of Array, result.convergent_framing
    assert_kind_of Array, result.convergent_omissions
    assert_kind_of Array, result.similar_coverage
  end

  test "returns empty result when article has no body text" do
    @root.update!(body_text: nil)
    result = Analyzers::CoordinatedNarrativeDetector.call(investigation: @investigation)

    assert_equal 0.0, result.coordination_score
    assert_equal [], result.similar_coverage
  end

  test "result struct has all expected fields" do
    result = Analyzers::CoordinatedNarrativeDetector.call(investigation: @investigation)

    assert_respond_to result, :coordination_score
    assert_respond_to result, :pattern_summary
    assert_respond_to result, :narrative_fingerprint
    assert_respond_to result, :similar_coverage
    assert_respond_to result, :convergent_omissions
    assert_respond_to result, :convergent_framing
  end
end
