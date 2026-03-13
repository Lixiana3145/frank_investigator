module Fetchers
  class HostCircuitBreaker
    FAILURE_THRESHOLD = 3
    COOLDOWN = 30.minutes

    def self.allow?(host)
      return true if host.blank?

      failures = Rails.cache.read(cache_key(host)).to_i
      failures < FAILURE_THRESHOLD
    end

    def self.record_failure!(host)
      return if host.blank?

      key = cache_key(host)
      current = Rails.cache.read(key).to_i
      Rails.cache.write(key, current + 1, expires_in: COOLDOWN)
    end

    def self.record_success!(host)
      return if host.blank?

      Rails.cache.write(cache_key(host), 0, expires_in: COOLDOWN)
    end

    def self.cache_key(host)
      "circuit:#{host}:failures"
    end
    private_class_method :cache_key
  end
end
