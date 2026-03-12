module ErrorReporting
  class DatabaseSubscriber
    def report(error, handled:, severity:, context: {}, source: nil)
      fingerprint = Digest::SHA256.hexdigest("#{error.class}:#{error.message.to_s.truncate(200)}")
      now = Time.current

      existing = ErrorReport.find_by(fingerprint: fingerprint)
      if existing
        existing.update!(
          last_occurred_at: now,
          occurrences_count: existing.occurrences_count + 1,
          context: context.presence || existing.context
        )
      else
        ErrorReport.create!(
          error_class: error.class.name,
          message: error.message.to_s.truncate(2000),
          backtrace: clean_backtrace(error).first(20)&.join("\n"),
          severity: severity.to_s,
          source: source,
          context: context.presence || {},
          fingerprint: fingerprint,
          first_occurred_at: now,
          last_occurred_at: now
        )
      end
    rescue StandardError => e
      Rails.logger.error("[ErrorReporting] Failed to persist error report: #{e.message}")
    end

    private

    def clean_backtrace(error)
      return [] unless error.backtrace

      Rails.backtrace_cleaner.clean(error.backtrace).presence || error.backtrace.first(20)
    end
  end
end
