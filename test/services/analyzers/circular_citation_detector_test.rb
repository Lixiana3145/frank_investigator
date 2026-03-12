require "test_helper"

class CircularCitationDetectorTest < ActiveSupport::TestCase
  setup do
    @article_a = Article.create!(
      url: "https://news1.com/gossip", normalized_url: "https://news1.com/gossip-#{SecureRandom.hex(4)}",
      host: "news1.com", title: "Celebrity scandal breaks", fetch_status: :fetched,
      body_text: "A" * 200, authority_tier: :secondary, authority_score: 0.5
    )
    @article_b = Article.create!(
      url: "https://news2.com/scandal", normalized_url: "https://news2.com/scandal-#{SecureRandom.hex(4)}",
      host: "news2.com", title: "Scandal confirmed", fetch_status: :fetched,
      body_text: "B" * 200, authority_tier: :secondary, authority_score: 0.5
    )
  end

  test "detects circular citations between two articles" do
    # A cites B and B cites A
    ArticleLink.create!(source_article: @article_a, target_article: @article_b, href: @article_b.url, follow_status: :crawled)
    ArticleLink.create!(source_article: @article_b, target_article: @article_a, href: @article_a.url, follow_status: :crawled)

    result = Analyzers::CircularCitationDetector.call(articles: [@article_a, @article_b])

    assert_equal 1, result.circular_pairs.size
    assert_includes result.circular_pairs.first[:article_ids], @article_a.id
    assert_includes result.circular_pairs.first[:article_ids], @article_b.id
  end

  test "no circular when links are one-directional" do
    ArticleLink.create!(source_article: @article_a, target_article: @article_b, href: @article_b.url, follow_status: :crawled)

    result = Analyzers::CircularCitationDetector.call(articles: [@article_a, @article_b])
    assert_empty result.circular_pairs
  end

  test "detects thin chain when article has no outbound citations" do
    result = Analyzers::CircularCitationDetector.call(articles: [@article_a])

    assert_equal 1, result.thin_chains.size
    assert_equal "no_outbound_citations", result.thin_chains.first[:reason]
  end

  test "does not flag primary source as thin chain" do
    @article_a.update!(authority_tier: :primary)

    result = Analyzers::CircularCitationDetector.call(articles: [@article_a])
    assert_empty result.thin_chains
  end

  test "detects thin chain when article only cites evidence set members" do
    ArticleLink.create!(source_article: @article_a, target_article: @article_b, href: @article_b.url, follow_status: :crawled)

    result = Analyzers::CircularCitationDetector.call(articles: [@article_a, @article_b])

    # article_a cites article_b (within set), article_b has no outbound links
    thin_a = result.thin_chains.find { |t| t[:article_id] == @article_a.id }
    assert_equal "cites_only_evidence_set", thin_a[:reason]
  end

  test "grounded article has external substantive citation" do
    external = Article.create!(
      url: "https://gov.br/data", normalized_url: "https://gov.br/data-#{SecureRandom.hex(4)}",
      host: "gov.br", title: "Official data", fetch_status: :fetched,
      body_text: "X" * 200, authority_tier: :primary, authority_score: 0.95
    )
    ArticleLink.create!(source_article: @article_a, target_article: external, href: external.url, follow_status: :crawled)

    result = Analyzers::CircularCitationDetector.call(articles: [@article_a])

    assert_equal 1, result.grounded_count
    assert_equal 0, result.ungrounded_count
    assert_empty result.thin_chains
  end

  test "citation_depth_score penalizes circular and thin patterns" do
    ArticleLink.create!(source_article: @article_a, target_article: @article_b, href: @article_b.url, follow_status: :crawled)
    ArticleLink.create!(source_article: @article_b, target_article: @article_a, href: @article_a.url, follow_status: :crawled)

    result = Analyzers::CircularCitationDetector.call(articles: [@article_a, @article_b])

    assert_operator result.citation_depth_score, :<, 0.5
  end
end
