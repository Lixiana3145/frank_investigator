require "test_helper"

class Articles::SyncClaimsTest < ActiveSupport::TestCase
  test "creates canonical claims and claim assessments for an article" do
    article = Article.create!(
      url: "https://example.com/news",
      normalized_url: "https://example.com/news",
      host: "example.com",
      title: "City Hall says taxes will fall in 2026",
      body_text: "City Hall announced taxes will fall by 4 percent in 2026. Officials said the plan was approved yesterday."
    )
    investigation = Investigation.create!(submitted_url: article.url, normalized_url: article.normalized_url, root_article: article)

    Articles::SyncClaims.call(investigation:, article:)

    assert_operator Claim.count, :>=, 2
    assert_equal Claim.count, investigation.claim_assessments.count
    assert_equal article.article_claims.count, article.claims.count
  end
end
