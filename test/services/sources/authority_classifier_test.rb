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

  test "classifies camara hosts as legislative records" do
    result = Sources::AuthorityClassifier.call(
      url: "https://www.camara.leg.br/noticias/1234-projeto-de-lei-avanca/",
      host: "www.camara.leg.br",
      title: "Projeto de lei avanca"
    )

    assert_equal :legislative_record, result.source_kind
    assert_equal :primary, result.authority_tier
    assert_equal "leg.br", result.independence_group
  end

  test "classifies brazilian courts as court records" do
    result = Sources::AuthorityClassifier.call(
      url: "https://portal.stf.jus.br/noticias/verNoticiaDetalhe.asp?idConteudo=123",
      host: "portal.stf.jus.br",
      title: "STF julga acao"
    )

    assert_equal :court_record, result.source_kind
    assert_equal :primary, result.authority_tier
    assert_equal "jus.br", result.independence_group
  end

  test "classifies cvm and b3 style market pages as company filings" do
    result = Sources::AuthorityClassifier.call(
      url: "https://www.rad.cvm.gov.br/ENET/frmExibirArquivoIPEExterno.aspx?numSequencia=1",
      host: "www.rad.cvm.gov.br",
      title: "Fato relevante PETR4"
    )

    assert_equal :company_filing, result.source_kind
    assert_equal :primary, result.authority_tier
    assert_operator result.authority_score, :>=, 0.9
  end

  test "classifies column URLs as opinion columns" do
    result = Sources::AuthorityClassifier.call(
      url: "https://www1.folha.uol.com.br/colunas/exemplo/2026/04/titulo.shtml",
      host: "www1.folha.uol.com.br",
      title: "Exemplo"
    )

    assert_equal :news_article, result.source_kind
    assert_equal :opinion_column, result.source_role
  end

  test "classifies blog hosts as blog amplification" do
    result = Sources::AuthorityClassifier.call(
      url: "https://blogdopaulinho.com.br/2026/04/12/exemplo/",
      host: "blogdopaulinho.com.br",
      title: "Exemplo"
    )

    assert_equal :news_article, result.source_kind
    assert_equal :blog_amplification, result.source_role
  end

  test "classifies editorial URLs as editorials" do
    result = Sources::AuthorityClassifier.call(
      url: "https://example.com/editorial/economic-policy",
      host: "example.com",
      title: "Editorial: Economic Policy"
    )

    assert_equal :editorial, result.source_role
  end

  test "classifies vozes URLs as opinion columns" do
    result = Sources::AuthorityClassifier.call(
      url: "https://www.gazetadopovo.com.br/vozes/guilherme-fiuza/exemplo/",
      host: "www.gazetadopovo.com.br",
      title: "Exemplo"
    )

    assert_equal :opinion_column, result.source_role
  end
end
