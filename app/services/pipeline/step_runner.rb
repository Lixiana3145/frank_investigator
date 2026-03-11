module Pipeline
  class StepRunner
    STALE_AFTER = 10.minutes

    Result = Struct.new(:step, :executed, keyword_init: true)

    def self.call(investigation:, name:, &block)
      new(investigation:, name:).call(&block)
    end

    def initialize(investigation:, name:)
      @investigation = investigation
      @name = name
    end

    def call
      step = @investigation.pipeline_steps.find_or_create_by!(name: @name)

      step.with_lock do
        step.reload
        return Result.new(step:, executed: false) if step.completed?
        return Result.new(step:, executed: false) if step.running? && !stale?(step)

        step.update!(
          status: :running,
          attempts_count: step.attempts_count + 1,
          started_at: step.started_at || Time.current,
          error_class: nil,
          error_message: nil
        )
      end

      result_json = yield(step) || {}
      step.update!(status: :completed, finished_at: Time.current, result_json:)

      Result.new(step:, executed: true)
    rescue StandardError => error
      step&.update!(
        status: :failed,
        finished_at: Time.current,
        error_class: error.class.name,
        error_message: error.message
      )
      raise
    end

    private

    def stale?(step)
      step.started_at.blank? || step.started_at < STALE_AFTER.ago
    end
  end
end
