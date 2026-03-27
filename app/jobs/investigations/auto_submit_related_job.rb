module Investigations
  # After cross-referencing completes, auto-submit the most relevant
  # related articles found by the coordinated narrative detector.
  # This builds the cross-investigation composite automatically.
  #
  # Limits: max 2 auto-submissions per investigation to control cost.
  # Skips URLs that are already investigated.
  class AutoSubmitRelatedJob < ApplicationJob
    queue_as :default

    MAX_AUTO_SUBMISSIONS = 2

    def perform(investigation_id)
      investigation = Investigation.find(investigation_id)
      return unless investigation.completed?

      # Get URLs found by the coordinated narrative detector
      coverage = Array(investigation.coordinated_narrative&.dig("similar_coverage"))
      return if coverage.empty?

      submitted = 0
      coverage.each do |item|
        break if submitted >= MAX_AUTO_SUBMISSIONS

        url = item["url"].to_s
        next if url.blank?

        # Skip if already investigated
        normalized = begin
          Investigations::UrlNormalizer.call(url)
        rescue StandardError
          next
        end
        next if Investigation.exists?(normalized_url: normalized)

        # Skip if URL is rejected by classifier
        begin
          Investigations::UrlClassifier.call(normalized)
        rescue Investigations::UrlClassifier::RejectedUrlError
          next
        end

        # Submit for investigation
        new_inv = Investigations::EnsureStarted.call(submitted_url: normalized)
        Rails.logger.info("[AutoSubmit] Auto-submitted #{normalized.truncate(60)} from investigation #{investigation.slug}")
        submitted += 1
      rescue StandardError => e
        Rails.logger.warn("[AutoSubmit] Failed to submit #{url&.truncate(60)}: #{e.message}")
      end
    end
  end
end
