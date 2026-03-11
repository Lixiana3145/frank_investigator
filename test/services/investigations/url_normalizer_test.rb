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

  test "raises for invalid urls" do
    assert_raises(Investigations::UrlNormalizer::InvalidUrlError) do
      Investigations::UrlNormalizer.call("not a valid url")
    end
  end
end
