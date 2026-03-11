require "test_helper"

class Sources::ConnectorRouterTest < ActiveSupport::TestCase
  test "extracts structured metadata for government records" do
    result = Sources::ConnectorRouter.call(
      url: "https://www.gov.br/fazenda/pt-br/assuntos/exemplo",
      host: "www.gov.br",
      title: "Lei 123 reduz imposto",
      html: <<~HTML,
        <html>
          <head>
            <meta property="og:site_name" content="Gov.br">
            <meta property="article:published_time" content="2026-03-10T10:30:00-03:00">
          </head>
          <body>
            <article>
              <p>Lei 123 reduz imposto e altera regras fiscais.</p>
            </article>
          </body>
        </html>
      HTML
      source_kind: :government_record,
      authority_tier: :primary,
      authority_score: 0.98
    )

    assert_equal :government_record, result.source_kind
    assert_equal :primary, result.authority_tier
    assert_equal "government_record", result.metadata_json["connector"]
    assert result.published_at.present?
  end

  test "extracts doi metadata for scientific papers" do
    result = Sources::ConnectorRouter.call(
      url: "https://doi.org/10.1000/test",
      host: "doi.org",
      title: "Study on vaccines",
      html: <<~HTML,
        <html>
          <head>
            <meta name="citation_doi" content="10.1000/test">
            <meta name="description" content="Abstract text">
          </head>
          <body></body>
        </html>
      HTML
      source_kind: :scientific_paper,
      authority_tier: :primary,
      authority_score: 0.93
    )

    assert_equal :scientific_paper, result.source_kind
    assert_equal "10.1000/test", result.metadata_json["doi"]
    assert_equal "Abstract text", result.metadata_json["abstract"]
  end
end
