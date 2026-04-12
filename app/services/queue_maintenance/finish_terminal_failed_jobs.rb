module QueueMaintenance
  class FinishTerminalFailedJobs
    def self.call(now: Time.current)
      new(now:).call
    end

    def initialize(now:)
      @now = now
    end

    def call
      terminal_failed_jobs.update_all(finished_at: @now, updated_at: @now)
    end

    private

    def terminal_failed_jobs
      SolidQueue::Job.where(finished_at: nil)
        .where(id: SolidQueue::FailedExecution.select(:job_id))
        .where.not(id: SolidQueue::ReadyExecution.select(:job_id))
        .where.not(id: SolidQueue::ClaimedExecution.select(:job_id))
        .where.not(id: SolidQueue::ScheduledExecution.select(:job_id))
        .where.not(id: SolidQueue::BlockedExecution.select(:job_id))
    end
  end
end
