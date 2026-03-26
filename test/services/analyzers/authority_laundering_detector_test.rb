require "test_helper"

class Analyzers::AuthorityLaunderingDetectorTest < ActiveSupport::TestCase
  setup do
    @root = Article.create!(
      url: "https://altest.com/article", normalized_url: "https://altest.com/article",
      host: "altest.com", fetch_status: :fetched,
      body_text: "According to reports, the scandal was first reported by a small blog and then picked up by major outlets.",
      title: "Scandal Spreads Across Media"
    )
    @investigation = Investigation.create!(
      submitted_url: @root.url, normalized_url: @root.normalized_url,
      root_article: @root, status: :processing
    )
  end

  test "returns valid result" do
    result = Analyzers::AuthorityLaunderingDetector.call(investigation: @investigation)

    assert_kind_of Analyzers::AuthorityLaunderingDetector::Result, result
    assert_kind_of Array, result.chains
    assert_includes 0.0..1.0, result.laundering_score
    assert_kind_of Integer, result.circular_citations_found
    assert result.summary.present?
  end

  test "returns empty result when no body text" do
    @root.update!(body_text: nil)
    result = Analyzers::AuthorityLaunderingDetector.call(investigation: @investigation)

    assert_equal [], result.chains
    assert_equal 0.0, result.laundering_score
    assert_equal 0, result.circular_citations_found
    assert result.summary.present?
  end

  test "result struct has expected fields" do
    result = Analyzers::AuthorityLaunderingDetector.call(investigation: @investigation)

    assert_respond_to result, :chains
    assert_respond_to result, :laundering_score
    assert_respond_to result, :circular_citations_found
    assert_respond_to result, :summary
  end
end
