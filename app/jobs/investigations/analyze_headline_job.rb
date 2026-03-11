module Investigations
  class AnalyzeHeadlineJob < ApplicationJob
    queue_as :default

    def perform(investigation_id)
      investigation = Investigation.includes(:root_article).find(investigation_id)

      Pipeline::StepRunner.call(investigation:, name: "analyze_headline") do
        article = investigation.root_article || raise("Investigation is missing a root article")
        result = Analyzers::HeadlineBaitAnalyzer.call(title: article.title, body_text: article.body_text)

        investigation.update!(headline_bait_score: result.score)

        { headline_bait_score: result.score, reason: result.reason }
      end
    ensure
      Investigations::RefreshStatus.call(investigation) if investigation
    end
  end
end
