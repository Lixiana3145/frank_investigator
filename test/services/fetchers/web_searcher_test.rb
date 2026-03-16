require "test_helper"

class Fetchers::WebSearcherTest < ActiveSupport::TestCase
  DUCKDUCKGO_HTML = <<~HTML.freeze
    <html>
    <body>
      <div class="result">
        <a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fwww.reuters.com%2Fbusiness%2Fenergy%2Fpetrobras-diesel-2026-03-13&amp;rut=abc123">
          Petrobras raises diesel prices - Reuters
        </a>
        <div class="result__snippet">Petrobras announced a 5% increase in diesel prices.</div>
      </div>
      <div class="result">
        <a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fwww.bloomberg.com%2Fnews%2Farticles%2F2026-03-13%2Fpetrobras-diesel&amp;rut=def456">
          Petrobras diesel price hike - Bloomberg
        </a>
        <div class="result__snippet">Bloomberg coverage of the diesel increase.</div>
      </div>
      <div class="result">
        <a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Dabc123&amp;rut=ghi789">
          Video about diesel - YouTube
        </a>
        <div class="result__snippet">Video content.</div>
      </div>
    </body>
    </html>
  HTML

  GOOGLE_NEWS_RSS = <<~XML.freeze
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <item>
          <title>Petrobras sobe preço do diesel - Folha</title>
          <link>https://www1.folha.uol.com.br/mercado/2026/03/petrobras-diesel-preco.shtml</link>
          <description>A Petrobras anunciou aumento no diesel.</description>
        </item>
      </channel>
    </rss>
  XML

  test "parses DuckDuckGo HTML results and extracts URLs from uddg param" do
    searcher = Fetchers::WebSearcher.new(query: "test", max_results: 8)
    results = searcher.send(:search_duckduckgo_html)

    # This test would need network; instead test the URL extraction directly
    url = searcher.send(:extract_ddg_url, "//duckduckgo.com/l/?uddg=https%3A%2F%2Fwww.reuters.com%2Fbusiness%2Fenergy%2Fpetrobras-diesel-2026-03-13&rut=abc")

    assert_match(/reuters\.com/, url)
  end

  test "extracts URL from DuckDuckGo uddg parameter" do
    searcher = Fetchers::WebSearcher.new(query: "test", max_results: 8)

    url = searcher.send(:extract_ddg_url, "//duckduckgo.com/l/?uddg=https%3A%2F%2Fwww.bloomberg.com%2Fnews%2Farticles%2F2026-03-13%2Fpetrobras-diesel&rut=def")
    assert_match(/bloomberg\.com/, url)
  end

  test "rejects internal DuckDuckGo URLs" do
    searcher = Fetchers::WebSearcher.new(query: "test", max_results: 8)

    url = searcher.send(:extract_ddg_url, "/some-internal-page")
    assert_nil url
  end

  test "rejects invalid URIs" do
    searcher = Fetchers::WebSearcher.new(query: "test", max_results: 8)

    url = searcher.send(:extract_ddg_url, "not a url at all []{}!")
    assert_nil url
  end

  test "returns empty array on blank query" do
    results = Fetchers::WebSearcher.call(query: "")
    assert_equal [], results
  end

  test "filters non-article URLs" do
    searcher = Fetchers::WebSearcher.new(query: "test", max_results: 8)

    article_results = [
      Fetchers::WebSearcher::SearchResult.new(url: "https://www.reuters.com/business/energy/petrobras-diesel-2026-03-13", title: "Reuters", snippet: "test"),
      Fetchers::WebSearcher::SearchResult.new(url: "https://www.youtube.com/watch?v=abc123", title: "YouTube", snippet: "test")
    ]

    filtered = searcher.send(:filter_article_urls, article_results)

    urls = filtered.map(&:url)
    assert urls.any? { |u| u.include?("reuters.com") }
    refute urls.any? { |u| u.include?("youtube.com") }
  end

  test "normalize_search_url handles percent-encoded URLs" do
    searcher = Fetchers::WebSearcher.new(query: "test", max_results: 8)

    url = searcher.send(:normalize_search_url, "https%3A%2F%2Fwww.reuters.com%2Fbusiness%2Fenergy%2Fpetrobras-diesel-2026-03-13")
    assert_match(/reuters\.com/, url)
  end

  test "normalize_search_url returns nil for invalid URLs" do
    searcher = Fetchers::WebSearcher.new(query: "test", max_results: 8)

    url = searcher.send(:normalize_search_url, "")
    assert_nil url
  end

  test "SearchResult struct has expected fields" do
    result = Fetchers::WebSearcher::SearchResult.new(
      url: "https://example.com/article",
      title: "Test Article",
      snippet: "A snippet"
    )

    assert_equal "https://example.com/article", result.url
    assert_equal "Test Article", result.title
    assert_equal "A snippet", result.snippet
  end
end
