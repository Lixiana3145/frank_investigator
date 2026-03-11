module Analyzers
  class ActiveEvidenceRetriever
    SEARCH_URL_TEMPLATES = {
      us_legislation: "https://www.congress.gov/search?q=%{query}",
      brazil_legislation: "https://www.camara.leg.br/busca-portal?contextoBusca=BuscaProposicoes&termo=%{query}",
      us_statistics: "https://fred.stlouisfed.org/searchresults/?st=%{query}",
      brazil_statistics: "https://sidra.ibge.gov.br/pesquisar?q=%{query}",
      us_sec_filing: "https://efts.sec.gov/LATEST/search-index?q=%{query}",
      brazil_market: "https://www.b3.com.br/pt_br/pesquise/?query=%{query}",
      biomedical: "https://pubmed.ncbi.nlm.nih.gov/?term=%{query}",
      us_court: "https://www.courtlistener.com/?q=%{query}",
      brazil_court: "https://portal.stf.jus.br/processos/listarProcessos.asp?consulta=%{query}",
      oversight: "https://www.gao.gov/search?query=%{query}",
      budget_fiscal: "https://www.cbo.gov/search/results/%{query}"
    }.freeze

    MAX_FETCHES_PER_CLAIM = 3
    FETCH_TIMEOUT = 15_000

    def self.call(investigation:, claim:)
      new(investigation:, claim:).call
    end

    def initialize(investigation:, claim:)
      @investigation = investigation
      @claim = claim
    end

    def call
      queries = AuthorityQueryGenerator.call(claim: @claim).first(5)
      return [] if queries.empty?

      fetched = 0
      results = []

      queries.each do |query|
        break if fetched >= MAX_FETCHES_PER_CLAIM

        # Skip if we already have evidence from this authority type
        next if already_has_evidence_from?(query.suggested_hosts)

        url = search_url_for(query)
        next unless url

        article = fetch_and_persist(url, query)
        if article
          fetched += 1
          results << article
          link_to_claim(article)
        end
      end

      results
    end

    private

    def already_has_evidence_from?(hosts)
      @claim.articles.fetched.where(host: hosts).exists?
    end

    def search_url_for(query)
      template = SEARCH_URL_TEMPLATES[query.authority_type.to_sym]
      return nil unless template

      encoded_query = ERB::Util.url_encode(query.query_text.truncate(100))
      template % { query: encoded_query }
    end

    def fetch_and_persist(url, query)
      normalized = begin
        Investigations::UrlNormalizer.call(url)
      rescue Investigations::UrlNormalizer::InvalidUrlError
        return nil
      end

      existing = Article.find_by(normalized_url: normalized)
      return existing if existing&.fetched?

      article = Article.find_or_create_by!(normalized_url: normalized) do |a|
        a.url = url
        a.host = URI.parse(normalized).host
        a.fetch_status = :pending
      end
    rescue ActiveRecord::RecordNotUnique
      Article.find_by!(normalized_url: normalized)
    else
      return article if article.fetched?

      begin
        fetcher = fetcher_class.constantize.new
        snapshot = fetcher.call(url)
        Articles::PersistFetchedContent.call(article:, html: snapshot.html, title: snapshot.title, investigation: @investigation)
        article.reload
      rescue StandardError => e
        Rails.logger.warn("Active retrieval fetch failed for #{url}: #{e.message}")
        article.update!(fetch_status: :failed) unless article.fetched?
        nil
      end
    end

    def link_to_claim(article)
      ArticleClaim.find_or_create_by!(
        article:,
        claim: @claim,
        role: :linked_source
      ) do |ac|
        ac.surface_text = @claim.canonical_text.truncate(500)
        ac.stance = :cites
        ac.importance_score = 0.7
      end
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def fetcher_class
      Rails.application.config.x.frank_investigator.fetcher_class
    end
  end
end
