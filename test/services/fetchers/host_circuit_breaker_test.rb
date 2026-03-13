require "test_helper"

class Fetchers::HostCircuitBreakerTest < ActiveSupport::TestCase
  setup do
    @host = "failing-host-#{SecureRandom.hex(4)}.example.com"
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "allows requests when no failures recorded" do
    assert Fetchers::HostCircuitBreaker.allow?(@host)
  end

  test "allows requests below failure threshold" do
    2.times { Fetchers::HostCircuitBreaker.record_failure!(@host) }
    assert Fetchers::HostCircuitBreaker.allow?(@host)
  end

  test "blocks requests at failure threshold" do
    3.times { Fetchers::HostCircuitBreaker.record_failure!(@host) }
    assert_not Fetchers::HostCircuitBreaker.allow?(@host)
  end

  test "success resets failure count" do
    3.times { Fetchers::HostCircuitBreaker.record_failure!(@host) }
    assert_not Fetchers::HostCircuitBreaker.allow?(@host)

    Fetchers::HostCircuitBreaker.record_success!(@host)
    assert Fetchers::HostCircuitBreaker.allow?(@host)
  end

  test "allows blank host" do
    assert Fetchers::HostCircuitBreaker.allow?(nil)
    assert Fetchers::HostCircuitBreaker.allow?("")
  end

  test "record_failure! is safe with blank host" do
    assert_nothing_raised { Fetchers::HostCircuitBreaker.record_failure!(nil) }
  end
end
