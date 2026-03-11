require "test_helper"

class Investigations::FetchRootArticleJobTest < ActiveJob::TestCase
  setup do
    @previous_fetcher = Rails.application.config.x.frank_investigator.fetcher_class
    Rails.application.config.x.frank_investigator.fetcher_class = "Fetchers::FakeFetcher"
    Fetchers::FakeFetcher.clear
  end

  teardown do
    Rails.application.config.x.frank_investigator.fetcher_class = @previous_fetcher
    Fetchers::FakeFetcher.clear
  end

  test "fetches and extracts the root article without duplicating links on rerun" do
    investigation = Investigations::EnsureStarted.call(submitted_url: "https://example.com/news")

    Fetchers::FakeFetcher.register(
      "https://example.com/news",
      html: <<~HTML
        <html>
          <head><title>City Hall says taxes will fall in 2026</title></head>
          <body>
            <header><a href="https://ignore.example.com">Ignore me</a></header>
            <article>
              <p>City Hall announced taxes will fall by 4 percent in 2026.</p>
              <p>The article cites the full budget document.</p>
              <p><a href="https://example.com/budget">Budget document</a></p>
            </article>
          </body>
        </html>
      HTML
    )

    perform_enqueued_jobs only: Investigations::KickoffJob
    Investigations::FetchRootArticleJob.perform_now(investigation.id)
    Investigations::FetchRootArticleJob.perform_now(investigation.id)

    investigation.reload

    assert_equal "fetched", investigation.root_article.fetch_status
    assert_equal 1, investigation.root_article.sourced_links.count
    assert_equal "https://example.com/budget", investigation.root_article.sourced_links.first.href
    assert_equal "completed", investigation.pipeline_steps.find_by!(name: "fetch_root_article").status
  end
end
