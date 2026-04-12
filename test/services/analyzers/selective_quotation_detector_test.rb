require "test_helper"

class Analyzers::SelectiveQuotationDetectorTest < ActiveSupport::TestCase
  setup do
    @root = Article.create!(
      url: "https://sqtest.com/article", normalized_url: "https://sqtest.com/article",
      host: "sqtest.com", fetch_status: :fetched,
      body_text: 'The minister said "we will consider raising taxes" during the press conference. According to experts, "the economy is in freefall and nothing can save it" warned the analyst.',
      title: "Minister Plans Tax Hike"
    )
    @investigation = Investigation.create!(
      submitted_url: @root.url, normalized_url: @root.normalized_url,
      root_article: @root, status: :processing
    )
  end

  test "returns valid result" do
    result = Analyzers::SelectiveQuotationDetector.call(investigation: @investigation)

    assert_kind_of Analyzers::SelectiveQuotationDetector::Result, result
    assert_kind_of Array, result.quotations
    assert_includes 0.0..1.0, result.quotation_integrity_score
    assert result.summary.present?
  end

  test "returns empty result when no body text" do
    @root.update!(body_text: nil)
    result = Analyzers::SelectiveQuotationDetector.call(investigation: @investigation)

    assert_equal [], result.quotations
    assert_equal 1.0, result.quotation_integrity_score
    assert result.summary.present?
  end

  test "result struct has expected fields" do
    result = Analyzers::SelectiveQuotationDetector.call(investigation: @investigation)

    assert_respond_to result, :quotations
    assert_respond_to result, :quotation_integrity_score
    assert_respond_to result, :summary
  end

  test "response schema marks every declared item property as required" do
    schema = Analyzers::SelectiveQuotationDetector.new(investigation: @investigation).send(:response_schema)
    item_schema = schema.dig(:schema, :properties, :quotations, :items)

    assert_equal item_schema[:properties].keys.map(&:to_s).sort, item_schema[:required].sort
  end
end
