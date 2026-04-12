require "test_helper"

class Analyzers::CrossInvestigationEnricherTest < ActiveSupport::TestCase
  test "matches related investigations with shared subject and opposing fiscal framing" do
    root_a = Article.create!(
      url: "https://example.com/a",
      normalized_url: "https://example.com/a",
      host: "example.com",
      title: "Haddad foi um bom ministro",
      body_text: "O artigo argumenta que Haddad foi um bom ministro, mas discute Fazenda, impostos e resultado fiscal.",
      fetch_status: :fetched
    )
    inv_a = Investigation.create!(submitted_url: root_a.url, normalized_url: root_a.normalized_url, root_article: root_a, status: :completed)
    claim_a = Claim.create!(
      canonical_text: "Haddad foi um bom ministro.",
      canonical_fingerprint: "haddad-bom-ministro",
      checkability_status: :not_checkable
    )
    ClaimAssessment.create!(investigation: inv_a, claim: claim_a, verdict: :not_checkable, checkability_status: :not_checkable)

    root_b = Article.create!(
      url: "https://example.com/b",
      normalized_url: "https://example.com/b",
      host: "example.org",
      title: "Após aumentos de impostos, Haddad deixa Ministério da Fazenda",
      body_text: "A reportagem afirma que Haddad deixou o Ministério da Fazenda após aumentos de impostos e piora do quadro fiscal.",
      fetch_status: :fetched
    )
    inv_b = Investigation.create!(submitted_url: root_b.url, normalized_url: root_b.normalized_url, root_article: root_b, status: :completed)
    claim_b = Claim.create!(
      canonical_text: "Após aumentos de impostos, Haddad deixa Ministério da Fazenda.",
      canonical_fingerprint: "haddad-impostos-fazenda",
      checkability_status: :checkable
    )
    ClaimAssessment.create!(investigation: inv_b, claim: claim_b, verdict: :supported, checkability_status: :checkable)

    related = Analyzers::CrossInvestigationEnricher.new(investigation: inv_a).send(:find_related_investigations)

    assert_includes related, inv_b
  end

  test "does not match unrelated investigations that only share a public figure" do
    root_a = Article.create!(
      url: "https://example.com/c",
      normalized_url: "https://example.com/c",
      host: "example.com",
      title: "Haddad foi um bom ministro",
      body_text: "O texto discute Fazenda, impostos e política fiscal.",
      fetch_status: :fetched
    )
    inv_a = Investigation.create!(submitted_url: root_a.url, normalized_url: root_a.normalized_url, root_article: root_a, status: :completed)
    claim_a = Claim.create!(
      canonical_text: "Haddad foi um bom ministro.",
      canonical_fingerprint: "haddad-bom-ministro-2",
      checkability_status: :not_checkable
    )
    ClaimAssessment.create!(investigation: inv_a, claim: claim_a, verdict: :not_checkable, checkability_status: :not_checkable)

    root_b = Article.create!(
      url: "https://example.com/d",
      normalized_url: "https://example.com/d",
      host: "example.net",
      title: "Haddad participa de evento sobre educação digital",
      body_text: "A cobertura trata de educação digital, conectividade nas escolas e formação de professores para uso de tecnologia em sala de aula.",
      fetch_status: :fetched
    )
    inv_b = Investigation.create!(submitted_url: root_b.url, normalized_url: root_b.normalized_url, root_article: root_b, status: :completed)
    claim_b = Claim.create!(
      canonical_text: "Haddad participou de evento sobre educação digital.",
      canonical_fingerprint: "haddad-educacao-digital",
      checkability_status: :checkable
    )
    ClaimAssessment.create!(investigation: inv_b, claim: claim_b, verdict: :supported, checkability_status: :checkable)

    related = Analyzers::CrossInvestigationEnricher.new(investigation: inv_a).send(:find_related_investigations)

    refute_includes related, inv_b
  end
end
