module Llm
  class RubyLlmClient
    Result = Struct.new(:verdict, :confidence_score, :reason_summary, keyword_init: true)

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are part of a news fact-checking pipeline.
      Return only strict JSON with keys verdict, confidence_score, and reason_summary.
      Base the answer only on the provided evidence packet.
      Use verdict values: supported, disputed, mixed, needs_more_evidence, not_checkable.
    PROMPT

    def initialize(models: Rails.application.config.x.frank_investigator.openrouter_models)
      @models = Array(models)
    end

    def call(claim:, evidence_packet:)
      return nil unless available?

      results = @models.filter_map do |model|
        ask_model(model:, claim:, evidence_packet:)
      rescue StandardError
        nil
      end

      return nil if results.empty?

      majority_verdict = results.group_by(&:verdict).max_by { |_, votes| votes.length }&.first || "needs_more_evidence"
      mean_confidence = results.sum { |result| result.confidence_score.to_f } / results.size
      disagreement_penalty = results.map(&:verdict).uniq.one? ? 0 : 0.15

      Result.new(
        verdict: majority_verdict,
        confidence_score: [mean_confidence - disagreement_penalty, 0].max.round(2),
        reason_summary: results.first.reason_summary
      )
    end

    def available?
      defined?(RubyLLM) && ENV["OPENROUTER_API_KEY"].present? && @models.any?
    end

    private

    def ask_model(model:, claim:, evidence_packet:)
      response = RubyLLM.chat(model:, provider: :openrouter, assume_model_exists: true)
        .with_instructions(SYSTEM_PROMPT)
        .with_schema(response_schema)
        .ask(build_prompt(claim:, evidence_packet:))

      payload = response.content.is_a?(Hash) ? response.content : JSON.parse(response.content.to_s)
      Result.new(
        verdict: payload.fetch("verdict"),
        confidence_score: payload.fetch("confidence_score").to_f,
        reason_summary: payload.fetch("reason_summary")
      )
    end

    def build_prompt(claim:, evidence_packet:)
      {
        claim: claim.canonical_text,
        checkability_status: claim.checkability_status,
        evidence: evidence_packet
      }.to_json
    end

    def response_schema
      {
        name: "claim_assessment",
        schema: {
          type: "object",
          additionalProperties: false,
          properties: {
            verdict: {
              type: "string",
              enum: %w[supported disputed mixed needs_more_evidence not_checkable]
            },
            confidence_score: {
              type: "number"
            },
            reason_summary: {
              type: "string"
            }
          },
          required: %w[verdict confidence_score reason_summary]
        }
      }
    end
  end
end
