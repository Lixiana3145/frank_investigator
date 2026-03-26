require "test_helper"

class Analyzers::StatisticalDeceptionDetectorTest < ActiveSupport::TestCase
  setup do
    @root = Article.create!(
      url: "https://sdtest.com/article", normalized_url: "https://sdtest.com/article",
      host: "sdtest.com", fetch_status: :fetched,
      body_text: "Sales grew 300% last quarter. Crime rose by 40% compared to last year. The risk doubles with this treatment.",
      title: "Shocking Numbers Reveal Truth"
    )
    @investigation = Investigation.create!(
      submitted_url: @root.url, normalized_url: @root.normalized_url,
      root_article: @root, status: :processing
    )
  end

  test "returns valid result" do
    result = Analyzers::StatisticalDeceptionDetector.call(investigation: @investigation)

    assert_kind_of Analyzers::StatisticalDeceptionDetector::Result, result
    assert_kind_of Array, result.deceptions
    assert_includes 0.0..1.0, result.statistical_integrity_score
    assert result.summary.present?
  end

  test "returns empty result when no body text" do
    @root.update!(body_text: nil)
    result = Analyzers::StatisticalDeceptionDetector.call(investigation: @investigation)

    assert_equal [], result.deceptions
    assert_equal 1.0, result.statistical_integrity_score
    assert result.summary.present?
  end

  test "result struct has expected fields" do
    result = Analyzers::StatisticalDeceptionDetector.call(investigation: @investigation)

    assert_respond_to result, :deceptions
    assert_respond_to result, :statistical_integrity_score
    assert_respond_to result, :summary
  end
end
