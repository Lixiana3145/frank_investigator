require "test_helper"

class Analyzers::BatchContentAnalyzerTest < ActiveSupport::TestCase
  test "batch schema marks every declared item property as required" do
    article = Article.create!(
      url: "https://batchtest.com/article",
      normalized_url: "https://batchtest.com/article",
      host: "batchtest.com",
      fetch_status: :fetched,
      body_text: "Economic coverage with sourced claims and quotations.",
      title: "Batch Analyzer Test"
    )
    investigation = Investigation.create!(
      submitted_url: article.url,
      normalized_url: article.normalized_url,
      root_article: article,
      status: :processing
    )
    schema = Analyzers::BatchContentAnalyzer.new(investigation: investigation).send(:batch_schema)
    root_properties = schema.dig(:schema, :properties)

    assert_required_keys(root_properties[:source_misrepresentation][:properties][:misrepresentations][:items])
    assert_required_keys(root_properties[:temporal_manipulation][:properties][:manipulations][:items])
    assert_required_keys(root_properties[:statistical_deception][:properties][:deceptions][:items])
    assert_required_keys(root_properties[:selective_quotation][:properties][:quotations][:items])

    authority_chain = root_properties[:authority_laundering][:properties][:chains][:items]
    assert_required_keys(authority_chain)
    assert_required_keys(authority_chain[:properties][:steps][:items])
  end

  private

  def assert_required_keys(object_schema)
    assert_equal object_schema[:properties].keys.map(&:to_s).sort, object_schema[:required].sort
  end
end
