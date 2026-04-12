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

  test "heuristic fallback translation keys exist in english and portuguese" do
    keys = %w[
      heuristic_summary
      no_statistics
      no_percentages_summary
      multiplier_excerpt
      multiplier_explanation
      multiplier_corrective
      missing_base_excerpt.one
      missing_base_excerpt.other
      missing_base_explanation
      missing_base_corrective
      pct_of_pct_excerpt
      pct_of_pct_explanation
      pct_of_pct_corrective
    ]

    keys.each do |key|
      assert I18n.exists?("heuristic_fallbacks.statistical_deception.#{key}", :en), "missing en key #{key}"
      assert I18n.exists?("heuristic_fallbacks.statistical_deception.#{key}", :"pt-BR"), "missing pt-BR key #{key}"
    end
  end
end
