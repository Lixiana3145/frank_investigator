module Investigations
  class FetchLinkedArticleJob < ApplicationJob
    queue_as :default

    def perform(investigation_id, article_link_id)
      investigation = Investigation.find(investigation_id)
      article_link = ArticleLink.includes(:target_article).find(article_link_id)

      Pipeline::StepRunner.call(investigation:, name: "fetch_linked_article:#{article_link.id}") do
        article_link.reload
        return { skipped: true } if article_link.crawled? && article_link.target_article.fetched?

        article = article_link.target_article

        unless Fetchers::HostCircuitBreaker.allow?(article.host)
          article_link.update!(follow_status: :skipped)
          next { skipped: true, reason: "circuit_breaker" }
        end

        if article.fresh?
          Rails.logger.info("[FetchLinkedArticle] Article #{article.normalized_url} is fresh, skipping re-fetch")
        else
          snapshot = fetcher.call(article.normalized_url)
          Articles::PersistFetchedContent.call(
            article:,
            html: snapshot.html,
            fetched_title: snapshot.title,
            current_depth: article_link.depth
          )
          Fetchers::HostCircuitBreaker.record_success!(article.host)
        end

        article_link.update!(follow_status: :crawled)
        Investigations::ExpandLinkedArticlesJob.perform_later(investigation.id, source_article_id: article.id) if article_link.depth < max_depth
        Investigations::AssessClaimsJob.perform_later(investigation.id)

        { article_id: article.id, discovered_links_count: article.sourced_links.count, cached: article.fresh? }
      end
    rescue Fetchers::ChromiumFetcher::FetchError => error
      Fetchers::HostCircuitBreaker.record_failure!(article_link&.target_article&.host)
      article_link&.update!(follow_status: :failed)
      article_link&.target_article&.update!(fetch_status: :failed)
      raise error
    ensure
      Investigations::RefreshStatus.call(investigation) if investigation
    end

    private

    def fetcher
      Rails.application.config.x.frank_investigator.fetcher_class.constantize
    end

    def max_depth
      Rails.application.config.x.frank_investigator.max_link_depth
    end
  end
end
