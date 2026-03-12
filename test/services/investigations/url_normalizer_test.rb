require "test_helper"

class Investigations::UrlNormalizerTest < ActiveSupport::TestCase
  test "normalizes host case, strips fragment, and sorts query params" do
    normalized = Investigations::UrlNormalizer.call("HTTPS://Example.COM/news?id=2&a=1#section")

    assert_equal "https://example.com/news?a=1&id=2", normalized
  end

  test "adds https when the scheme is missing" do
    normalized = Investigations::UrlNormalizer.call("example.com/article")

    assert_equal "https://example.com/article", normalized
  end

  test "strips utm tracking parameters" do
    normalized = Investigations::UrlNormalizer.call(
      "https://example.com/article/123?utm_source=twitter&utm_medium=social&utm_campaign=spring"
    )

    assert_equal "https://example.com/article/123", normalized
  end

  test "strips Facebook click ID" do
    normalized = Investigations::UrlNormalizer.call(
      "https://example.com/news/story?fbclid=abc123def456"
    )

    assert_equal "https://example.com/news/story", normalized
  end

  test "strips Google Ads click ID" do
    normalized = Investigations::UrlNormalizer.call(
      "https://example.com/news/story?gclid=xyz789"
    )

    assert_equal "https://example.com/news/story", normalized
  end

  test "strips mixed tracking params but keeps content params" do
    normalized = Investigations::UrlNormalizer.call(
      "https://example.com/search?q=test&utm_source=google&page=2&fbclid=abc&id=42"
    )

    assert_equal "https://example.com/search?id=42&page=2&q=test", normalized
  end

  test "strips multiple tracking families at once" do
    normalized = Investigations::UrlNormalizer.call(
      "https://example.com/article?mc_cid=abc&mc_eid=def&_hsenc=ghi&_hsmi=jkl&gclsrc=manual"
    )

    assert_equal "https://example.com/article", normalized
  end

  test "strips Cloudflare challenge tokens" do
    normalized = Investigations::UrlNormalizer.call(
      "https://example.com/page?__cf_chl_tk=abc123"
    )

    assert_equal "https://example.com/page", normalized
  end

  test "strips Instagram share ID" do
    normalized = Investigations::UrlNormalizer.call(
      "https://example.com/post/123?igshid=abc123"
    )

    assert_equal "https://example.com/post/123", normalized
  end

  test "preserves query when only some params are junk" do
    normalized = Investigations::UrlNormalizer.call(
      "https://example.com/article?id=99&utm_source=newsletter"
    )

    assert_equal "https://example.com/article?id=99", normalized
  end

  test "removes query string entirely when all params are tracking" do
    normalized = Investigations::UrlNormalizer.call(
      "https://example.com/article/slug?utm_source=x&utm_medium=y&ref=z"
    )

    assert_equal "https://example.com/article/slug", normalized
  end

  test "raises for invalid urls" do
    assert_raises(Investigations::UrlNormalizer::InvalidUrlError) do
      Investigations::UrlNormalizer.call("not a valid url")
    end
  end
end
