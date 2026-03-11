module Investigations
  class FetchRootArticleJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      investigation = Investigation.includes(:root_article).find(investigation_id)

      Pipeline::StepRunner.call(investigation:, name: "fetch_root_article") do
        article = investigation.root_article || raise("Investigation is missing a root article")
        snapshot = fetcher.call(article.normalized_url)
        Articles::PersistFetchedContent.call(article:, html: snapshot.html, fetched_title: snapshot.title, current_depth: 0)

        ExtractClaimsJob.perform_later(investigation.id)
        AnalyzeHeadlineJob.perform_later(investigation.id)
        ExpandLinkedArticlesJob.perform_later(investigation.id, source_article_id: article.id)

        { links_count: article.sourced_links.count }
      end
    rescue Fetchers::ChromiumFetcher::FetchError => error
      investigation.root_article&.update!(fetch_status: :failed)
      raise error
    ensure
      Investigations::RefreshStatus.call(investigation) if investigation
    end

    private

    def fetcher
      Rails.application.config.x.frank_investigator.fetcher_class.constantize
    end
  end
end
