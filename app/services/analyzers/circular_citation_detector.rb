module Analyzers
  # Detects circular or thin citation chains in evidence articles.
  #
  # A "circular citation" occurs when articles in the evidence set cite each
  # other but none point to an independent primary source. A "thin chain"
  # occurs when Article A cites Article B as its source, but B itself has no
  # external evidence — making A's citation worthless for corroboration.
  #
  # These patterns are common in smear campaigns and viral misinformation:
  # outlets copy each other's reporting without anyone having original evidence.
  class CircularCitationDetector
    Result = Struct.new(
      :circular_pairs,
      :thin_chains,
      :grounded_count,
      :ungrounded_count,
      :citation_depth_score,
      keyword_init: true
    )

    def self.call(articles:)
      new(articles:).call
    end

    def initialize(articles:)
      @articles = articles
      @article_ids = Set.new(articles.map(&:id))
    end

    def call
      circular = detect_circular_citations
      thin = detect_thin_chains
      grounded, ungrounded = partition_grounded

      Result.new(
        circular_pairs: circular,
        thin_chains: thin,
        grounded_count: grounded,
        ungrounded_count: ungrounded,
        citation_depth_score: compute_depth_score(grounded, ungrounded, circular, thin)
      )
    end

    private

    # Two articles in the evidence set that cite each other (A→B and B→A)
    def detect_circular_citations
      return [] if @article_ids.size < 2

      internal_links = ArticleLink
        .where(source_article_id: @article_ids, target_article_id: @article_ids)
        .pluck(:source_article_id, :target_article_id)

      link_set = Set.new(internal_links.map { |s, t| [s, t] })
      pairs = []

      internal_links.each do |source_id, target_id|
        if link_set.include?([target_id, source_id]) && source_id < target_id
          pairs << { article_ids: [source_id, target_id] }
        end
      end

      pairs
    end

    # Articles in the evidence set whose outbound links only point to other
    # articles in the same evidence set (no external grounding), OR whose
    # cited sources themselves have no body text (empty/unfetched targets).
    def detect_thin_chains
      return [] if @article_ids.empty?

      thin = []

      @articles.each do |article|
        outbound = article.sourced_links.where(follow_status: "crawled")

        # No outbound links at all — article makes claims without citing sources
        if outbound.empty?
          # Only flag secondary/low-tier articles; primary sources ARE the evidence
          next if article.authority_tier == "primary"
          thin << { article_id: article.id, reason: "no_outbound_citations" }
          next
        end

        targets = outbound.includes(:target_article).map(&:target_article).compact

        # All cited targets are within our own evidence set (echo chamber)
        external_targets = targets.reject { |t| @article_ids.include?(t.id) }
        if external_targets.empty?
          thin << { article_id: article.id, reason: "cites_only_evidence_set" }
          next
        end

        # Cited external targets exist but have no substantive content
        substantive_externals = external_targets.select { |t| t.body_text.present? && t.body_text.length >= 100 }
        if substantive_externals.empty?
          thin << { article_id: article.id, reason: "cited_sources_unsubstantiated" }
        end
      end

      thin
    end

    # Count how many evidence articles have at least one outbound link to a
    # substantive external source (outside the evidence set).
    def partition_grounded
      grounded = 0
      ungrounded = 0

      @articles.each do |article|
        # Primary sources are inherently grounded — they ARE the evidence
        if article.authority_tier == "primary"
          grounded += 1
          next
        end

        external_substantive = article.sourced_links
          .where(follow_status: "crawled")
          .joins(:target_article)
          .where.not(target_article_id: @article_ids)
          .merge(Article.where("length(body_text) >= 100"))
          .exists?

        if external_substantive
          grounded += 1
        else
          ungrounded += 1
        end
      end

      [grounded, ungrounded]
    end

    def compute_depth_score(grounded, ungrounded, circular, thin)
      total = grounded + ungrounded
      return 0.5 if total.zero?

      base = grounded.to_f / total

      # Circular citations are a strong signal of echo chamber
      circular_penalty = [circular.size * 0.15, 0.4].min

      # Thin chains weaken the evidence base
      thin_penalty = [thin.size * 0.08, 0.3].min

      [base - circular_penalty - thin_penalty, 0.0].max.round(2)
    end
  end
end
