module Investigations
  class FetchRootArticleJob < ApplicationJob
    queue_as :fetch

    def perform(investigation_id)
      @investigation = Investigation.includes(:root_article).find(investigation_id)
      @article = @investigation.root_article

      Pipeline::StepRunner.call(investigation: @investigation, name: "fetch_root_article") do
        raise("Investigation is missing a root article") unless @article

        if @article.fresh?
          Rails.logger.info("[FetchRootArticle] Article #{@article.normalized_url} is fresh (fetched #{@article.fetched_at}), skipping re-fetch")
        else
          snapshot = fetcher.call(@article.normalized_url)
          Articles::PersistFetchedContent.call(article: @article, html: snapshot.html, fetched_title: snapshot.title, current_depth: 0)
        end

        { links_count: @article.sourced_links.count, cached: @article.fresh? }
      end
      @step_succeeded = true
    rescue Fetchers::ChromiumFetcher::FetchError => error
      @investigation.root_article&.update!(fetch_status: :failed)
      raise error
    ensure
      if @investigation
        if @step_succeeded && @article
          Investigations::ExtractClaimsJob.perform_later(@investigation.id)
          Investigations::AnalyzeHeadlineJob.perform_later(@investigation.id)
          Investigations::ExpandLinkedArticlesJob.perform_later(@investigation.id, source_article_id: @article.id)
        end
        Investigations::RefreshStatus.call(@investigation)
      end
    end

    private

    def fetcher
      Rails.application.config.x.frank_investigator.fetcher_class.constantize
    end
  end
end
