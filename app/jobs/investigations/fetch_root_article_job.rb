module Investigations
  class FetchRootArticleJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      investigation = Investigation.includes(:root_article).find(investigation_id)

      Pipeline::StepRunner.call(investigation:, name: "fetch_root_article") do
        article = investigation.root_article || raise("Investigation is missing a root article")
        snapshot = fetcher.call(article.normalized_url)
        extracted = Parsing::MainContentExtractor.call(html: snapshot.html, url: article.normalized_url)

        ApplicationRecord.transaction do
          article.update!(
            title: extracted.title.presence || snapshot.title,
            body_text: extracted.body_text,
            excerpt: extracted.excerpt,
            fetch_status: :fetched,
            fetched_at: Time.current,
            content_fingerprint: Digest::SHA256.hexdigest(extracted.body_text.to_s),
            main_content_path: extracted.main_content_path
          )

          upsert_links!(article, extracted.links)
        end

        ExtractClaimsJob.perform_later(investigation.id)
        AnalyzeHeadlineJob.perform_later(investigation.id)
        ExpandLinkedArticlesJob.perform_later(investigation.id)

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

    def upsert_links!(article, links)
      links.each do |link|
        target_article = Article.find_or_create_by!(normalized_url: link[:href]) do |record|
          record.url = link[:href]
          record.host = URI.parse(link[:href]).host
        end

        ArticleLink.find_or_initialize_by(source_article: article, href: link[:href]).tap do |record|
          record.target_article = target_article
          record.anchor_text = link[:anchor_text]
          record.context_excerpt = link[:context_excerpt]
          record.position = link[:position]
          record.depth = 1
          record.save!
        end
      end
    end
  end
end
