module Analyzers
  class AuthorityQueryGenerator
    Query = Struct.new(:authority_type, :query_text, :suggested_hosts, :priority, keyword_init: true)

    # Patterns that suggest specific authority types
    LAW_PATTERNS = /\b(lei|law|legislation|statute|decreto|decree|executive order|regulation|portaria|resolucao|bill|PL|PEC|medida provisoria)\b|H\.R\.\s*\d|S\.\s*\d/i
    COURT_PATTERNS = /\b(court|tribunal|ruling|judgment|sentence|acordao|julgamento|verdict|lawsuit|case\s+no|docket|habeas corpus|acao|processo)\b/i
    BUDGET_FISCAL_PATTERNS = /\b(budget|deficit|spending|fiscal|orcamento|receita|despesa|divida|debt|tax revenue|arrecadacao)\b/i
    STATISTICS_PATTERNS = /\b(percent|percentage|rate|index|indice|taxa|grew|growth|crescimento|declined|fell|rose|inflation|unemployment|GDP|PIB|IPCA|CPI|population|populacao|censo|census|survey|pesquisa)\b/i
    FINANCIAL_PATTERNS = /\b(stock|shares|filing|SEC|CVM|10-K|8-K|earnings|revenue|profit|faturamento|lucro|dividendo|IPO|oferta)\b/i
    HEALTH_PATTERNS = /\b(clinical|trial|study|vaccine|drug|medication|treatment|disease|mortality|mortalidade|aprovacao|anvisa|FDA)\b/i
    MONETARY_PATTERNS = /\b(interest rate|Selic|FOMC|monetary policy|central bank|banco central|Fed|inflation target|meta de inflacao)\b/i
    OVERSIGHT_PATTERNS = /\b(audit|GAO|TCU|CGU|inspector general|accountability|fraud|waste|irregularidade|fiscalizacao)\b/i

    def self.call(claim:)
      new(claim:).call
    end

    def initialize(claim:)
      @claim = claim
      @text = claim.canonical_text.to_s
    end

    def call
      queries = []
      queries.concat(law_queries) if @text.match?(LAW_PATTERNS)
      queries.concat(court_queries) if @text.match?(COURT_PATTERNS)
      queries.concat(budget_queries) if @text.match?(BUDGET_FISCAL_PATTERNS)
      queries.concat(statistics_queries) if @text.match?(STATISTICS_PATTERNS)
      queries.concat(financial_queries) if @text.match?(FINANCIAL_PATTERNS)
      queries.concat(health_queries) if @text.match?(HEALTH_PATTERNS)
      queries.concat(monetary_queries) if @text.match?(MONETARY_PATTERNS)
      queries.concat(oversight_queries) if @text.match?(OVERSIGHT_PATTERNS)
      queries.sort_by(&:priority)
    end

    private

    def law_queries
      queries = []
      queries << Query.new(
        authority_type: :us_legislation,
        query_text: extract_law_reference || @text.truncate(200),
        suggested_hosts: %w[congress.gov govinfo.gov federalregister.gov],
        priority: 1
      ) if @text.match?(/\b(law|legislation|bill|executive order|regulation)\b|H\.R\.\s*\d|S\.\s*\d/i)

      queries << Query.new(
        authority_type: :brazil_legislation,
        query_text: extract_brazil_law_reference || @text.truncate(200),
        suggested_hosts: %w[camara.leg.br senado.leg.br in.gov.br],
        priority: 1
      ) if @text.match?(/\b(lei|decreto|portaria|resolucao|medida provisoria|PL|PEC)\b/i)

      queries
    end

    def court_queries
      queries = []
      queries << Query.new(
        authority_type: :us_court,
        query_text: @text.truncate(200),
        suggested_hosts: %w[uscourts.gov courtlistener.com],
        priority: 2
      ) if @text.match?(/\b(court|ruling|lawsuit|case\s+no|docket)\b/i)

      queries << Query.new(
        authority_type: :brazil_court,
        query_text: @text.truncate(200),
        suggested_hosts: %w[stf.jus.br stj.jus.br],
        priority: 2
      ) if @text.match?(/\b(tribunal|acordao|julgamento|processo|habeas corpus|acao)\b/i)

      queries
    end

    def budget_queries
      [Query.new(
        authority_type: :budget_fiscal,
        query_text: @text.truncate(200),
        suggested_hosts: %w[cbo.gov gao.gov tcu.gov.br],
        priority: 2
      )]
    end

    def statistics_queries
      queries = []
      queries << Query.new(
        authority_type: :us_statistics,
        query_text: extract_statistic_reference || @text.truncate(200),
        suggested_hosts: %w[bls.gov census.gov fred.stlouisfed.org],
        priority: 1
      ) if @text.match?(/\b(percent|rate|index|GDP|CPI|unemployment|population|census|survey)\b/i)

      queries << Query.new(
        authority_type: :brazil_statistics,
        query_text: extract_statistic_reference || @text.truncate(200),
        suggested_hosts: %w[ibge.gov.br ipea.gov.br sidra.ibge.gov.br],
        priority: 1
      ) if @text.match?(/\b(taxa|indice|PIB|IPCA|populacao|censo|pesquisa|crescimento)\b/i)

      queries
    end

    def financial_queries
      queries = []
      queries << Query.new(
        authority_type: :us_sec_filing,
        query_text: @text.truncate(200),
        suggested_hosts: %w[sec.gov],
        priority: 2
      ) if @text.match?(/\b(SEC|10-K|8-K|filing|earnings|IPO)\b/i)

      queries << Query.new(
        authority_type: :brazil_market,
        query_text: @text.truncate(200),
        suggested_hosts: %w[cvm.gov.br b3.com.br],
        priority: 2
      ) if @text.match?(/\b(CVM|fato relevante|oferta|B3)\b/i)

      queries
    end

    def health_queries
      queries = []
      queries << Query.new(
        authority_type: :biomedical,
        query_text: @text.truncate(200),
        suggested_hosts: %w[pubmed.ncbi.nlm.nih.gov],
        priority: 3
      )

      queries << Query.new(
        authority_type: :brazil_health_regulatory,
        query_text: @text.truncate(200),
        suggested_hosts: %w[anvisa.gov.br datasus.saude.gov.br],
        priority: 2
      ) if @text.match?(/\b(anvisa|SUS|mortalidade)\b/i)

      queries
    end

    def monetary_queries
      queries = []
      queries << Query.new(
        authority_type: :us_monetary,
        query_text: @text.truncate(200),
        suggested_hosts: %w[federalreserve.gov fred.stlouisfed.org],
        priority: 1
      ) if @text.match?(/\b(Fed|FOMC|interest rate)\b/i)

      queries << Query.new(
        authority_type: :brazil_monetary,
        query_text: @text.truncate(200),
        suggested_hosts: %w[bcb.gov.br],
        priority: 1
      ) if @text.match?(/\b(Selic|banco central|Copom|meta de inflacao)\b/i)

      queries
    end

    def oversight_queries
      [Query.new(
        authority_type: :oversight,
        query_text: @text.truncate(200),
        suggested_hosts: %w[gao.gov cbo.gov tcu.gov.br cgu.gov.br],
        priority: 2
      )]
    end

    def extract_law_reference
      @text.match(/(H\.R\.\s*\d+|S\.\s*\d+|Executive Order\s*\d+|Public Law\s*\d+-\d+)/i)&.to_s
    end

    def extract_brazil_law_reference
      @text.match(/\b(Lei\s+(?:Complementar\s+)?\d+[\/.]\d*|PL\s*\d+\/\d+|PEC\s*\d+\/\d+|Decreto\s*\d+)\b/i)&.to_s
    end

    def extract_statistic_reference
      @text.match(/\b(CPI|GDP|PIB|IPCA|unemployment rate|taxa de desemprego|inflation|inflacao)\b[^\n]{0,80}/i)&.to_s
    end
  end
end
