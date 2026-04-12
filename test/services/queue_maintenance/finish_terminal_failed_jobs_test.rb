require "test_helper"

class QueueMaintenance::FinishTerminalFailedJobsTest < ActiveSupport::TestCase
  test "marks terminal failed jobs as finished without touching live jobs" do
    now = Time.zone.parse("2026-04-12 12:00:00 UTC")

    terminal_failed = SolidQueue::Job.create!(
      queue_name: "default",
      class_name: "Investigations::FetchRootArticleJob",
      arguments: '{"arguments":[1]}',
      created_at: 1.hour.ago,
      updated_at: 1.hour.ago
    )
    SolidQueue::ReadyExecution.where(job_id: terminal_failed.id).delete_all
    SolidQueue::FailedExecution.create!(job_id: terminal_failed.id, error: '{"message":"boom"}', created_at: 30.minutes.ago)

    live_failed = SolidQueue::Job.create!(
      queue_name: "default",
      class_name: "Investigations::FetchRootArticleJob",
      arguments: '{"arguments":[2]}',
      created_at: 1.hour.ago,
      updated_at: 1.hour.ago
    )
    SolidQueue::FailedExecution.create!(job_id: live_failed.id, error: '{"message":"still-live"}', created_at: 20.minutes.ago)
    SolidQueue::ReadyExecution.find_or_create_by!(job_id: live_failed.id) do |execution|
      execution.queue_name = "default"
      execution.priority = 0
      execution.created_at = 20.minutes.ago
    end

    QueueMaintenance::FinishTerminalFailedJobs.call(now:)

    assert_equal now.to_i, terminal_failed.reload.finished_at.to_i
    assert_equal now.to_i, terminal_failed.updated_at.to_i
    assert_nil live_failed.reload.finished_at
  end
end
