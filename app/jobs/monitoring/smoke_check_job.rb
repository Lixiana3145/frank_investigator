module Monitoring
  class SmokeCheckJob < ApplicationJob
    queue_as :default

    def perform
      results = Monitoring::SmokeCheck.run_all

      results.each do |result|
        level = case result.status
        when :ok then :info
        when :skip then :info
        when :degraded then :warn
        else :error
        end

        Rails.logger.public_send(level, "[SmokeCheck] #{result.check_name}: #{result.status} — #{result.message} (#{result.duration_ms}ms)")
      end

      failed = results.select { |r| r.status == :fail || r.status == :error }
      if failed.any?
        Rails.logger.error("[SmokeCheck] #{failed.size} check(s) failed: #{failed.map(&:check_name).join(', ')}")
      end
    end
  end
end
