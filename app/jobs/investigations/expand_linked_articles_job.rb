module Investigations
  class ExpandLinkedArticlesJob < ApplicationJob
    queue_as :default

    def perform(investigation_id, source_article_id:)
      investigation = Investigation.find(investigation_id)
      source_article = Article.includes(:sourced_links).find(source_article_id)

      Pipeline::StepRunner.call(investigation:, name: step_name(investigation, source_article_id)) do
        max_depth = Rails.application.config.x.frank_investigator.max_link_depth
        links = source_article.sourced_links.where(depth: ..max_depth, follow_status: "pending").limit(10)

        links.each do |link|
          FetchLinkedArticleJob.perform_later(investigation.id, link.id)
        end

        { enqueued_links_count: links.count }
      end
    ensure
      Investigations::RefreshStatus.call(investigation) if investigation
    end

    private

    def step_name(investigation, source_article_id)
      source_article_id == investigation.root_article_id ? "expand_linked_articles_root" : "expand_linked_articles:#{source_article_id}"
    end
  end
end
