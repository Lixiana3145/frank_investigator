require "test_helper"

class Investigations::FetchLinkedArticleJobTest < ActiveJob::TestCase
  setup do
    @previous_fetcher = Rails.application.config.x.frank_investigator.fetcher_class
    Rails.application.config.x.frank_investigator.fetcher_class = "Fetchers::FakeFetcher"
    Fetchers::FakeFetcher.clear
  end

  teardown do
    Rails.application.config.x.frank_investigator.fetcher_class = @previous_fetcher
    Fetchers::FakeFetcher.clear
  end

  test "fetches a linked article, catalogs its claims, and expands one level deeper" do
    root = Article.create!(url: "https://example.com/news", normalized_url: "https://example.com/news", host: "example.com", fetch_status: :fetched)
    linked = Article.create!(url: "https://source.example.com/report", normalized_url: "https://source.example.com/report", host: "source.example.com")
    investigation = Investigation.create!(submitted_url: root.url, normalized_url: root.normalized_url, root_article: root)
    link = ArticleLink.create!(source_article: root, target_article: linked, href: linked.normalized_url, depth: 1)

    Fetchers::FakeFetcher.register(
      linked.normalized_url,
      html: <<~HTML
        <html>
          <head><title>Budget report confirms a 4 percent tax reduction</title></head>
          <body>
            <article>
              <p>The budget report confirms a 4 percent tax reduction in 2026.</p>
              <p><a href="https://records.example.net/appendix">Appendix</a></p>
            </article>
          </body>
        </html>
      HTML
    )

    assert_enqueued_with(job: Investigations::AssessClaimsJob, args: [investigation.id]) do
      Investigations::FetchLinkedArticleJob.perform_now(investigation.id, link.id)
    end

    link.reload
    linked.reload

    assert_equal "crawled", link.follow_status
    assert_equal "fetched", linked.fetch_status
    assert linked.sourced_links.exists?(href: "https://records.example.net/appendix")
    assert linked.article_claims.exists?
    assert investigation.claim_assessments.exists?
  end
end
