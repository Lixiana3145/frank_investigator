require "test_helper"

class Sources::AuthorityClassifierTest < ActiveSupport::TestCase
  test "classifies government sources as primary" do
    result = Sources::AuthorityClassifier.call(
      url: "https://www.gov.br/fazenda/pt-br/assuntos/exemplo",
      host: "www.gov.br",
      title: "Comunicado"
    )

    assert_equal :government_record, result.source_kind
    assert_equal :primary, result.authority_tier
    assert_operator result.authority_score, :>=, 0.9
    assert_equal "gov.br", result.independence_group
  end

  test "classifies social hosts as low authority" do
    result = Sources::AuthorityClassifier.call(
      url: "https://x.com/example/status/123",
      host: "x.com",
      title: "Post"
    )

    assert_equal :social_post, result.source_kind
    assert_equal :low, result.authority_tier
    assert_operator result.authority_score, :<, 0.3
  end

  test "uses the brazilian source registry when a configured host matches" do
    result = Sources::AuthorityClassifier.call(
      url: "https://www.cartacapital.com.br/politica/exemplo/",
      host: "www.cartacapital.com.br",
      title: "Exemplo"
    )

    assert_equal :news_article, result.source_kind
    assert_equal :secondary, result.authority_tier
    assert_equal "cartacapital.com.br", result.independence_group
    assert_operator result.authority_score, :>, 0.6
  end

  test "classifies company filing hosts as primary" do
    result = Sources::AuthorityClassifier.call(
      url: "https://www.sec.gov/ixviewer/ix.html?doc=/Archives/edgar/data/test.htm",
      host: "www.sec.gov",
      title: "8-K"
    )

    assert_equal :company_filing, result.source_kind
    assert_equal :primary, result.authority_tier
    assert_operator result.authority_score, :>=, 0.9
  end
end
