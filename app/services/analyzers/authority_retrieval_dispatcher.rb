module Analyzers
  class AuthorityRetrievalDispatcher
    RetrievalResult = Struct.new(:query, :articles_found, keyword_init: true)

    MAX_QUERIES_PER_CLAIM = 5

    def self.call(investigation:, claim:, max_queries: MAX_QUERIES_PER_CLAIM)
      new(investigation:, claim:, max_queries:).call
    end

    def initialize(investigation:, claim:, max_queries:)
      @investigation = investigation
      @claim = claim
      @max_queries = max_queries
    end

    def call
      queries = AuthorityQueryGenerator.call(claim: @claim).first(@max_queries)
      return [] if queries.empty?

      queries.filter_map do |query|
        articles = find_or_create_authority_articles(query)
        next if articles.empty?

        link_articles_to_claim(articles)
        RetrievalResult.new(query:, articles_found: articles)
      end
    end

    private

    def find_or_create_authority_articles(query)
      existing = Article.where(host: query.suggested_hosts).fetched
        .where("body_text LIKE ?", "%#{sanitize_for_like(query.query_text.truncate(60))}%")
        .limit(3)
        .to_a

      return existing if existing.any?

      # Fallback: search the web with site: restriction
      search_query = "site:#{query.suggested_hosts.first} #{query.query_text.truncate(60)}"
      search_results = Fetchers::WebSearcher.call(query: search_query, max_results: 3)

      search_results.filter_map do |sr|
        host = begin
          URI.parse(sr.url).host
        rescue URI::InvalidURIError
          next
        end
        next unless query.suggested_hosts.any? { |h| host.end_with?(h) || h.end_with?(host) }
        fetch_and_persist_article(sr.url, sr.title)
      end.first(2)
    end

    def fetch_and_persist_article(url, title)
      normalized = Investigations::UrlNormalizer.call(url)

      existing = Article.find_by(normalized_url: normalized)
      return existing if existing&.fetched?

      article = Article.find_or_create_by!(normalized_url: normalized) do |a|
        a.url = url
        a.host = URI.parse(normalized).host
        a.fetch_status = :pending
      end

      return article if article.fetched?

      fetcher = fetcher_class.constantize.new
      snapshot = fetcher.call(url)
      Articles::PersistFetchedContent.call(
        article:,
        html: snapshot.html,
        fetched_title: snapshot.title,
        current_depth: 1
      )
      article.reload
    rescue StandardError => e
      Rails.logger.warn("Authority retrieval fetch failed for #{url}: #{e.message}")
      nil
    end

    def fetcher_class
      Rails.application.config.x.frank_investigator.fetcher_class
    end

    def link_articles_to_claim(articles)
      articles.each do |article|
        ArticleClaim.find_or_create_by!(
          article:,
          claim: @claim,
          role: :linked_source
        ) do |ac|
          ac.surface_text = @claim.canonical_text.truncate(500)
          ac.stance = :cites
          ac.importance_score = 0.6
        end
      rescue ActiveRecord::RecordNotUnique
        next
      end
    end

    def sanitize_for_like(text)
      text.gsub(/[%_\\]/) { |m| "\\#{m}" }
    end
  end
end
