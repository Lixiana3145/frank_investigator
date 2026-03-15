require "test_helper"

class Fetchers::ChromiumFetcherTest < ActiveSupport::TestCase
  test "has multiple user agents for rotation" do
    agents = Fetchers::ChromiumFetcher::USER_AGENTS
    assert_operator agents.size, :>=, 3, "Should have at least 3 user agents"
    assert agents.all? { |ua| ua.include?("Chrome/") }, "All user agents should be Chrome-based"
  end

  test "browser options include anti-detection flags" do
    options = Fetchers::ChromiumFetcher::BROWSER_OPTIONS[:browser_options]
    assert_includes options.keys, "disable-blink-features"
    assert_equal "AutomationControlled", options["disable-blink-features"]
    assert_includes options.keys, "no-sandbox"
  end

  test "consent selectors cover common patterns" do
    selectors = Fetchers::ChromiumFetcher::CONSENT_SELECTORS
    assert selectors.any? { |s| s.include?("Aceitar") }, "Should have Portuguese consent button"
    assert selectors.any? { |s| s.include?("Accept") }, "Should have English consent button"
    assert selectors.any? { |s| s.include?("lgpd") }, "Should have LGPD-specific selector"
    assert selectors.any? { |s| s.include?("cookie") }, "Should have cookie-specific selector"
  end

  test "interstitial detection identifies Cloudflare challenges" do
    fetcher = Fetchers::ChromiumFetcher.new
    assert fetcher.send(:interstitial?, "<html><body>cloudflare challenge-platform</body></html>")
    assert fetcher.send(:interstitial?, "<html><body>checking your browser before accessing</body></html>")
  end

  test "interstitial detection ignores pages with real content" do
    fetcher = Fetchers::ChromiumFetcher.new
    # A page with cloudflare script reference BUT substantial content should NOT be flagged
    html = "<html><body><p>#{' substantial content. ' * 50}</p><script src='challenges.cloudflare.com/x.js'></script></body></html>"
    refute fetcher.send(:interstitial?, html)
  end

  test "interstitial detection ignores normal pages" do
    fetcher = Fetchers::ChromiumFetcher.new
    refute fetcher.send(:interstitial?, "<html><body><p>Normal news article about economics.</p></body></html>")
  end

  test "returns Snapshot struct with html and title" do
    snapshot = Fetchers::ChromiumFetcher::Snapshot.new(html: "<html></html>", title: "Test")
    assert_equal "<html></html>", snapshot.html
    assert_equal "Test", snapshot.title
  end
end
