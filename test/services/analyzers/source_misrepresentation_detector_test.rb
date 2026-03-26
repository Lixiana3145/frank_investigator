require "test_helper"

class Analyzers::SourceMisrepresentationDetectorTest < ActiveSupport::TestCase
  setup do
    @root = Article.create!(
      url: "https://smtest.com/article", normalized_url: "https://smtest.com/article",
      host: "smtest.com", fetch_status: :fetched,
      body_text: "A new study shows that coffee causes cancer, according to researchers at Harvard.",
      title: "Coffee Causes Cancer, Study Shows"
    )
    @investigation = Investigation.create!(
      submitted_url: @root.url, normalized_url: @root.normalized_url,
      root_article: @root, status: :processing
    )
  end

  test "returns valid result" do
    result = Analyzers::SourceMisrepresentationDetector.call(investigation: @investigation)

    assert_kind_of Analyzers::SourceMisrepresentationDetector::Result, result
    assert_kind_of Array, result.misrepresentations
    assert_includes 0.0..1.0, result.misrepresentation_score
    assert result.summary.present?
  end

  test "returns empty result when no body text" do
    @root.update!(body_text: nil)
    result = Analyzers::SourceMisrepresentationDetector.call(investigation: @investigation)

    assert_equal [], result.misrepresentations
    assert_equal 0.0, result.misrepresentation_score
    assert result.summary.present?
  end

  test "result struct has expected fields" do
    result = Analyzers::SourceMisrepresentationDetector.call(investigation: @investigation)

    assert_respond_to result, :misrepresentations
    assert_respond_to result, :misrepresentation_score
    assert_respond_to result, :summary
  end
end
