module Analyzers
  class ClaimAssessor
    Result = Struct.new(
      :verdict,
      :confidence_score,
      :checkability_status,
      :reason_summary,
      :missing_evidence_summary,
      :conflict_score,
      :authority_score,
      :independence_score,
      :timeliness_score,
      keyword_init: true
    )

    def self.call(investigation:, claim:)
      new(investigation:, claim:).call
    end

    def initialize(investigation:, claim:)
      @investigation = investigation
      @claim = claim
    end

    def call
      if @claim.not_checkable?
        return Result.new(
          verdict: :not_checkable,
          confidence_score: 0.9,
          checkability_status: :not_checkable,
          reason_summary: "This statement reads as opinion, rhetoric, or framing rather than a verifiable factual claim.",
          missing_evidence_summary: "No public evidence set can conclusively verify a subjective statement.",
          conflict_score: 0,
          authority_score: 0,
          independence_score: 0,
          timeliness_score: 0
        )
      end

      linked_supporting_articles = supporting_articles
      authority_score = [linked_supporting_articles.count * 0.18, 0.75].min
      independence_score = [linked_supporting_articles.map(&:host).uniq.count * 0.16, 0.65].min
      timeliness_score = @investigation.root_article&.fetched_at.present? ? 0.6 : 0.1
      heuristic_confidence = (0.15 + authority_score + independence_score + timeliness_score).clamp(0, 0.95)
      llm_result = llm_client.call(claim: @claim, evidence_packet:) if llm_client_available?

      Result.new(
        verdict: (llm_result&.verdict || "needs_more_evidence").to_sym,
        confidence_score: (llm_result&.confidence_score || heuristic_confidence).round(2),
        checkability_status: :checkable,
        reason_summary: llm_result&.reason_summary || "This looks like a factual claim, but the current evidence packet is still limited.",
        missing_evidence_summary: "Need corroborating primary or independent sources before supporting or disputing the claim.",
        conflict_score: linked_supporting_articles.count > 1 ? 0.15 : 0.25,
        authority_score: authority_score.round(2),
        independence_score: independence_score.round(2),
        timeliness_score: timeliness_score.round(2)
      )
    end

    private

    def evidence_packet
      supporting_articles.map do |article|
        {
          url: article.normalized_url,
          title: article.title,
          excerpt: article.excerpt,
          fetched_at: article.fetched_at
        }
      end
    end

    def supporting_articles
      @supporting_articles ||= @claim.articles.fetched.where.not(id: @investigation.root_article_id).distinct
    end

    def llm_client
      @llm_client ||= Llm::ClientFactory.build
    end

    def llm_client_available?
      llm_client.respond_to?(:available?) ? llm_client.available? : true
    end
  end
end
