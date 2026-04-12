require "test_helper"

class Pipeline::ResumeInterruptedTest < ActiveSupport::TestCase
  setup do
    clear_enqueued_jobs
  end

  test "re-enqueues kickoff for queued investigation with no pipeline steps" do
    article = Article.create!(url: "https://example.com/resume-kickoff", normalized_url: "https://example.com/resume-kickoff", host: "example.com")
    investigation = Investigation.create!(
      submitted_url: article.url,
      normalized_url: article.normalized_url,
      root_article: article,
      status: :queued
    )

    assert_enqueued_with(job: Investigations::KickoffJob, args: [ investigation.id ]) do
      Pipeline::ResumeInterrupted.call
    end
  end

  test "ignores terminal failed jobs when deciding whether to resume" do
    investigation = create_processing_investigation("https://example.com/resume-failed")
    investigation.pipeline_steps.create!(name: "kickoff", status: :completed, finished_at: Time.current)
    create_failed_queue_job(investigation, "Investigations::FetchRootArticleJob")

    assert_enqueued_with(job: Investigations::FetchRootArticleJob, args: [ investigation.id ]) do
      Pipeline::ResumeInterrupted.call
    end
  end

  test "does not enqueue a duplicate when the job is still live in the ready queue" do
    investigation = create_processing_investigation("https://example.com/resume-live")
    investigation.pipeline_steps.create!(name: "kickoff", status: :completed, finished_at: Time.current)
    create_ready_queue_job(investigation, "Investigations::FetchRootArticleJob")

    assert_no_enqueued_jobs only: Investigations::FetchRootArticleJob do
      Pipeline::ResumeInterrupted.call
    end
  end

  private

  def create_processing_investigation(url)
    article = Article.create!(url:, normalized_url: url, host: URI.parse(url).host)
    Investigation.create!(
      submitted_url: url,
      normalized_url: url,
      root_article: article,
      status: :processing
    )
  end

  def create_failed_queue_job(investigation, class_name)
    job = SolidQueue::Job.create!(
      queue_name: "default",
      class_name:,
      arguments: %({"arguments":[#{investigation.id}]}),
      created_at: Time.current,
      updated_at: Time.current
    )

    SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
    SolidQueue::ClaimedExecution.where(job_id: job.id).delete_all
    SolidQueue::ScheduledExecution.where(job_id: job.id).delete_all
    SolidQueue::BlockedExecution.where(job_id: job.id).delete_all
    SolidQueue::FailedExecution.create!(job_id: job.id, error: '{"message":"boom"}', created_at: Time.current)
  end

  def create_ready_queue_job(investigation, class_name)
    job = SolidQueue::Job.create!(
      queue_name: "default",
      class_name:,
      arguments: %({"arguments":[#{investigation.id}]}),
      created_at: Time.current,
      updated_at: Time.current
    )

    SolidQueue::ReadyExecution.find_or_create_by!(job_id: job.id) do |execution|
      execution.queue_name = "default"
      execution.priority = 0
      execution.created_at = Time.current
    end
  end
end
