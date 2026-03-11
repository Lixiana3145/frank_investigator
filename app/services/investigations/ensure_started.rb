module Investigations
  class EnsureStarted
    def self.call(submitted_url:)
      new(submitted_url:).call
    end

    def initialize(submitted_url:)
      @submitted_url = submitted_url
    end

    def call
      normalized_url = UrlNormalizer.call(@submitted_url)

      investigation = ApplicationRecord.transaction do
        article = Article.find_or_create_by!(normalized_url:) do |record|
          record.url = normalized_url
          record.host = URI.parse(normalized_url).host
        end

        Investigation.find_or_create_by!(normalized_url:) do |record|
          record.submitted_url = @submitted_url
          record.root_article = article
        end.tap do |record|
          if record.root_article_id.nil? || record.submitted_url != @submitted_url
            record.update!(submitted_url: @submitted_url, root_article: article)
          end
        end
      end

      Investigations::KickoffJob.perform_later(investigation.id)
      investigation
    end
  end
end
