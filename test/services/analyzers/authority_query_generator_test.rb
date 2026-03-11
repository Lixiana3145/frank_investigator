require "test_helper"

class Analyzers::AuthorityQueryGeneratorTest < ActiveSupport::TestCase
  test "generates US legislation queries for law-related claims" do
    claim = build_claim("H.R. 1234 would increase the federal minimum wage to $20")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    law_query = queries.find { |q| q.authority_type == :us_legislation }
    assert_not_nil law_query
    assert_includes law_query.suggested_hosts, "congress.gov"
    assert_match(/H\.R\.\s*1234/, law_query.query_text)
  end

  test "generates Brazil legislation queries for Brazilian law claims" do
    claim = build_claim("O PL 1234/2026 reduz o imposto de renda para empresas")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    law_query = queries.find { |q| q.authority_type == :brazil_legislation }
    assert_not_nil law_query
    assert_includes law_query.suggested_hosts, "camara.leg.br"
  end

  test "generates statistics queries for numeric claims" do
    claim = build_claim("Unemployment rate fell to 3.5 percent in February")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    stats_query = queries.find { |q| q.authority_type == :us_statistics }
    assert_not_nil stats_query
    assert_includes stats_query.suggested_hosts, "bls.gov"
  end

  test "generates Brazil statistics queries for IPCA claims" do
    claim = build_claim("O IPCA acumulou alta de 4,5% nos ultimos 12 meses")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    stats_query = queries.find { |q| q.authority_type == :brazil_statistics }
    assert_not_nil stats_query
    assert_includes stats_query.suggested_hosts, "ibge.gov.br"
    assert_match(/IPCA/, stats_query.query_text)
  end

  test "generates SEC queries for filing-related claims" do
    claim = build_claim("Tesla filed an 8-K with the SEC reporting record earnings")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    sec_query = queries.find { |q| q.authority_type == :us_sec_filing }
    assert_not_nil sec_query
    assert_includes sec_query.suggested_hosts, "sec.gov"
  end

  test "generates court queries for judicial claims" do
    claim = build_claim("The Supreme Court ruled the law unconstitutional in case no 123")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    court_query = queries.find { |q| q.authority_type == :us_court }
    assert_not_nil court_query
    assert_includes court_query.suggested_hosts, "uscourts.gov"
  end

  test "generates Brazil court queries for tribunal claims" do
    claim = build_claim("O STF julgou a acao e determinou a suspensao do decreto")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    court_query = queries.find { |q| q.authority_type == :brazil_court }
    assert_not_nil court_query
    assert_includes court_query.suggested_hosts, "stf.jus.br"
  end

  test "generates monetary queries for Selic claims" do
    claim = build_claim("O Copom elevou a Selic para 14,25% ao ano")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    monetary_query = queries.find { |q| q.authority_type == :brazil_monetary }
    assert_not_nil monetary_query
    assert_includes monetary_query.suggested_hosts, "bcb.gov.br"
  end

  test "generates oversight queries for audit claims" do
    claim = build_claim("GAO audit found $1.2 billion in wasteful spending")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    oversight_query = queries.find { |q| q.authority_type == :oversight }
    assert_not_nil oversight_query
    assert_includes oversight_query.suggested_hosts, "gao.gov"
  end

  test "generates health queries for biomedical claims" do
    claim = build_claim("A clinical trial showed the new drug reduces mortality by 30%")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    health_query = queries.find { |q| q.authority_type == :biomedical }
    assert_not_nil health_query
    assert_includes health_query.suggested_hosts, "pubmed.ncbi.nlm.nih.gov"
  end

  test "returns empty for claims with no authority signals" do
    claim = build_claim("The weather was nice today")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    assert_empty queries
  end

  test "queries are sorted by priority" do
    claim = build_claim("The unemployment rate fell to 3.5% according to H.R. 1234 budget analysis from GAO")
    queries = Analyzers::AuthorityQueryGenerator.call(claim:)

    assert queries.length > 1
    priorities = queries.map(&:priority)
    assert_equal priorities, priorities.sort
  end

  private

  def build_claim(text)
    Claim.new(
      canonical_text: text,
      canonical_fingerprint: Digest::SHA256.hexdigest(text),
      checkability_status: :checkable
    )
  end
end
