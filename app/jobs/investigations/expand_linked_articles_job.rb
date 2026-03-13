module Investigations
  class ExpandLinkedArticlesJob < ApplicationJob
    queue_as :default

    def perform(investigation_id, source_article_id:)
      investigation = Investigation.find(investigation_id)
      source_article = Article.includes(:sourced_links).find(source_article_id)

      Pipeline::StepRunner.call(investigation:, name: step_name(investigation, source_article_id)) do
        max_depth = Rails.application.config.x.frank_investigator.max_link_depth
        links = prioritized_links(source_article, max_depth)

        links.each do |link|
          Investigations::FetchLinkedArticleJob.perform_later(investigation.id, link.id)
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

    def prioritized_links(source_article, max_depth)
      candidates = source_article.sourced_links
        .includes(:target_article)
        .where(depth: ..max_depth, follow_status: "pending")
        .to_a
        .reject { |link| url_rejected?(link.target_article.normalized_url) }
        .sort_by { |link| [ source_priority(link.target_article), -link.target_article.authority_score.to_f, link.depth, link.position ] }

      # Enforce host diversity: max 3 per host
      selected = []
      host_counts = Hash.new(0)
      candidates.each do |link|
        host = link.target_article.host
        next if host_counts[host] >= 3
        selected << link
        host_counts[host] += 1
        break if selected.size >= 10
      end
      selected
    end

    def url_rejected?(url)
      Investigations::UrlClassifier.call(url)
      false
    rescue Investigations::UrlClassifier::RejectedUrlError
      true
    end

    def source_priority(article)
      case article.source_kind
      when "government_record", "legislative_record", "court_record", "scientific_paper", "company_filing" then 0
      when "press_release" then 1
      when "news_article" then 2
      else
        3
      end
    end
  end
end
