require "test_helper"

class HtmlFixtureTest < ActiveSupport::TestCase
  FIXTURE_DIR = Rails.root.join("test/fixtures/html")

  test "congress.gov bill fixture extracts correctly" do
    html = File.read(FIXTURE_DIR.join("congress_gov_bill.html"))
    result = Parsing::MainContentExtractor.call(html:)

    assert_includes result.title, "Infrastructure Investment and Jobs Act"
    assert_includes result.body_text, "$550 billion"
    assert_includes result.body_text, "Public Law 117-58"
  end

  test "IBGE statistics fixture extracts correctly" do
    html = File.read(FIXTURE_DIR.join("ibge_statistics.html"))
    result = Parsing::MainContentExtractor.call(html:)

    assert_includes result.title, "IPCA"
    assert_includes result.body_text, "4,83%"
    assert_includes result.body_text, "Alimentação e bebidas"
  end

  test "SEC filing fixture extracts correctly" do
    html = File.read(FIXTURE_DIR.join("sec_filing_10k.html"))
    result = Parsing::MainContentExtractor.call(html:)

    assert_includes result.title, "10-K"
    assert_includes result.body_text, "CIK: 0000320193"
    assert_includes result.body_text, "$412.3 billion"
  end

  test "STF ruling fixture extracts correctly" do
    html = File.read(FIXTURE_DIR.join("stf_ruling.html"))
    result = Parsing::MainContentExtractor.call(html:)

    assert_includes result.title, "ADI 6341"
    assert_includes result.body_text, "competência concorrente"
    assert_includes result.body_text, "Edson Fachin"
  end

  test "Folha news fixture extracts correctly" do
    html = File.read(FIXTURE_DIR.join("folha_news_article.html"))
    result = Parsing::MainContentExtractor.call(html:)

    assert_includes result.title, "R$ 50 bilhões"
    assert_includes result.body_text, "500 mil empregos"
    assert_includes result.body_text, "BNDES"
  end

  test "FRED statistics fixture extracts correctly" do
    html = File.read(FIXTURE_DIR.join("fred_statistics.html"))
    result = Parsing::MainContentExtractor.call(html:)

    assert_includes result.body_text, "CPIAUCSL"
    assert_includes result.body_text, "2.9 percent"
    assert_includes result.body_text, "Bureau of Labor Statistics"
  end

  test "connectors classify fixtures correctly" do
    fixtures = {
      "congress_gov_bill.html" => { host: "congress.gov", expected_kind: "legislative_record" },
      "ibge_statistics.html" => { host: "ibge.gov.br", expected_kind: "government_record" },
      "sec_filing_10k.html" => { host: "sec.gov", expected_kind: "company_filing" },
      "stf_ruling.html" => { host: "stf.jus.br", expected_kind: "court_record" },
      "fred_statistics.html" => { host: "fred.stlouisfed.org", expected_kind: "government_record" }
    }

    fixtures.each do |filename, spec|
      classification = Sources::AuthorityClassifier.call(host: spec[:host], url: "https://#{spec[:host]}/test")
      assert_equal spec[:expected_kind], classification.source_kind.to_s,
        "#{filename}: expected #{spec[:expected_kind]} for #{spec[:host]}, got #{classification.source_kind}"
    end
  end
end
