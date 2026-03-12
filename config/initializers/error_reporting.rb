Rails.application.configure do
  # Always subscribe the local database reporter
  config.after_initialize do
    Rails.error.subscribe(ErrorReporting::DatabaseSubscriber.new)

    # Sentry (optional): add `gem "sentry-rails"` to Gemfile and set SENTRY_DSN
    if defined?(Sentry) && ENV["SENTRY_DSN"].present?
      Sentry.init do |sentry_config|
        sentry_config.dsn = ENV["SENTRY_DSN"]
        sentry_config.breadcrumbs_logger = [ :active_support_logger ]
        sentry_config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.1).to_f
        sentry_config.environment = Rails.env
      end
      Rails.logger.info("[ErrorReporting] Sentry enabled")
    end

    # Honeybadger (optional): add `gem "honeybadger"` to Gemfile and set HONEYBADGER_API_KEY
    if defined?(Honeybadger) && ENV["HONEYBADGER_API_KEY"].present?
      Rails.logger.info("[ErrorReporting] Honeybadger enabled")
    end
  end
end
