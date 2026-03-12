require "test_helper"

class ErrorReporting::DatabaseSubscriberTest < ActiveSupport::TestCase
  setup do
    @subscriber = ErrorReporting::DatabaseSubscriber.new
  end

  test "report creates a new error report" do
    error = RuntimeError.new("something broke")
    error.set_backtrace(caller)

    assert_difference "ErrorReport.count", 1 do
      @subscriber.report(error, handled: false, severity: :error, source: "test")
    end

    report = ErrorReport.last
    assert_equal "RuntimeError", report.error_class
    assert_equal "something broke", report.message
    assert_equal "error", report.severity
    assert_equal "test", report.source
    assert_equal 1, report.occurrences_count
    assert report.backtrace.present?
  end

  test "report deduplicates by fingerprint and increments count" do
    error = RuntimeError.new("duplicate error")
    error.set_backtrace(caller)

    @subscriber.report(error, handled: false, severity: :error)
    @subscriber.report(error, handled: false, severity: :error)
    @subscriber.report(error, handled: false, severity: :error)

    assert_equal 1, ErrorReport.where(error_class: "RuntimeError", message: "duplicate error").count
    assert_equal 3, ErrorReport.where(error_class: "RuntimeError", message: "duplicate error").first.occurrences_count
  end

  test "report stores context" do
    error = StandardError.new("ctx test")
    error.set_backtrace(caller)

    @subscriber.report(error, handled: true, severity: :warning, context: { user_id: 42 })

    report = ErrorReport.last
    assert_equal "warning", report.severity
    assert_equal({ "user_id" => 42 }, report.context)
  end

  test "report does not raise on internal errors" do
    error = RuntimeError.new("test")
    error.set_backtrace(caller)

    subscriber = ErrorReporting::DatabaseSubscriber.new
    # Simulate a DB error by passing an error with a message that will cause fingerprint collision
    # with a broken record
    ErrorReport.create!(
      error_class: "RuntimeError", message: "test", fingerprint: Digest::SHA256.hexdigest("RuntimeError:test"),
      severity: "error", first_occurred_at: Time.current, last_occurred_at: Time.current
    )

    # This should not raise even though there's already a record
    assert_nothing_raised do
      subscriber.report(error, handled: false, severity: :error)
    end
  end

  test "purge_old removes old reports" do
    old = ErrorReport.create!(
      error_class: "OldError", message: "old", fingerprint: "old_fp",
      severity: "error", first_occurred_at: 31.days.ago, last_occurred_at: 31.days.ago
    )
    recent = ErrorReport.create!(
      error_class: "NewError", message: "new", fingerprint: "new_fp",
      severity: "error", first_occurred_at: 1.day.ago, last_occurred_at: 1.day.ago
    )

    ErrorReport.purge_old

    assert_not ErrorReport.exists?(old.id)
    assert ErrorReport.exists?(recent.id)
  end
end
