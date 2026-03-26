require "test_helper"

class Analyzers::TemporalManipulationDetectorTest < ActiveSupport::TestCase
  setup do
    @root = Article.create!(
      url: "https://tmtest.com/article", normalized_url: "https://tmtest.com/article",
      host: "tmtest.com", fetch_status: :fetched,
      body_text: "Unemployment is at 12%, according to data from 2019. The economy has been struggling recently.",
      title: "Economy in Crisis"
    )
    @investigation = Investigation.create!(
      submitted_url: @root.url, normalized_url: @root.normalized_url,
      root_article: @root, status: :processing
    )
  end

  test "returns valid result" do
    result = Analyzers::TemporalManipulationDetector.call(investigation: @investigation)

    assert_kind_of Analyzers::TemporalManipulationDetector::Result, result
    assert_kind_of Array, result.manipulations
    assert_includes 0.0..1.0, result.temporal_integrity_score
    assert result.summary.present?
  end

  test "returns empty result when no body text" do
    @root.update!(body_text: nil)
    result = Analyzers::TemporalManipulationDetector.call(investigation: @investigation)

    assert_equal [], result.manipulations
    assert_equal 1.0, result.temporal_integrity_score
    assert result.summary.present?
  end

  test "result struct has expected fields" do
    result = Analyzers::TemporalManipulationDetector.call(investigation: @investigation)

    assert_respond_to result, :manipulations
    assert_respond_to result, :temporal_integrity_score
    assert_respond_to result, :summary
  end
end
