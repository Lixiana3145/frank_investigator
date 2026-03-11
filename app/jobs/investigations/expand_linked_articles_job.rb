module Investigations
  class ExpandLinkedArticlesJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      investigation = Investigation.includes(root_article: :sourced_links).find(investigation_id)

      Pipeline::StepRunner.call(investigation:, name: "expand_linked_articles") do
        max_depth = Rails.application.config.x.frank_investigator.max_link_depth
        links = investigation.root_article&.sourced_links&.where(depth: 1)&.limit(10) || []

        links.each do |link|
          if link.depth > max_depth
            link.update!(follow_status: :skipped)
            next
          end

          link.update!(follow_status: :crawled)
        end

        { crawled_links_count: links.count }
      end
    ensure
      Investigations::RefreshStatus.call(investigation) if investigation
    end
  end
end
