module Llm
  class RubyLlmClient
    Result = Struct.new(:verdict, :confidence_score, :reason_summary, keyword_init: true)

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are part of a news fact-checking pipeline. Your task is to assess a claim based on retrieved evidence.

      Rules:
      - Base your assessment ONLY on the provided evidence, not your own knowledge.
      - Cite specific evidence items by their source URL or title in your reasoning.
      - If evidence is insufficient to reach a conclusion, say so explicitly.
      - If sources disagree, note the disagreement and which sources are more authoritative.
      - Be conservative: prefer "needs_more_evidence" over weak "supported" or "disputed".

      Return only strict JSON with keys: verdict, confidence_score, reason_summary.
      Use verdict values: supported, disputed, mixed, needs_more_evidence, not_checkable.
      confidence_score must be between 0.0 and 0.97.
      reason_summary must reference specific evidence sources.
    PROMPT

    def initialize(models: Rails.application.config.x.frank_investigator.openrouter_models)
      @models = Array(models)
    end

    def call(claim:, evidence_packet:, investigation: nil, claim_assessment: nil)
      return nil unless available?

      prompt_text = build_prompt(claim:, evidence_packet:)
      packet_fingerprint = Digest::SHA256.hexdigest(prompt_text)

      results = @models.filter_map do |model|
        ask_model(
          model:, claim:, evidence_packet:,
          prompt_text:, packet_fingerprint:,
          investigation:, claim_assessment:
        )
      rescue StandardError
        nil
      end

      return nil if results.empty?

      aggregate_results(results)
    end

    def available?
      defined?(RubyLLM) && ENV["OPENROUTER_API_KEY"].present? && @models.any?
    end

    private

    def aggregate_results(results)
      verdict_groups = results.group_by(&:verdict)
      majority_verdict = verdict_groups.max_by { |_, votes| votes.length }&.first || "needs_more_evidence"
      mean_confidence = results.sum { |r| r.confidence_score.to_f } / results.size

      # Penalize disagreement
      unique_verdicts = results.map(&:verdict).uniq
      disagreement_penalty = if unique_verdicts.one?
        0
      elsif unique_verdicts.size == 2
        0.12
      else
        0.2
      end

      # Pick the best reason from majority group
      majority_results = verdict_groups[majority_verdict] || results
      best_reason = majority_results.max_by { |r| r.reason_summary.to_s.length }&.reason_summary

      Result.new(
        verdict: majority_verdict,
        confidence_score: [mean_confidence - disagreement_penalty, 0].max.round(2),
        reason_summary: best_reason
      )
    end

    def ask_model(model:, claim:, evidence_packet:, prompt_text:, packet_fingerprint:, investigation:, claim_assessment:)
      if investigation && (cached = LlmInteraction.find_cached(evidence_packet_fingerprint: packet_fingerprint, model_id: model))
        return parse_response(cached.response_json)
      end

      interaction = create_interaction(
        investigation:, claim_assessment:, model:, prompt_text:, packet_fingerprint:
      )

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = RubyLLM.chat(model:, provider: :openrouter, assume_model_exists: true)
        .with_instructions(SYSTEM_PROMPT)
        .with_schema(response_schema)
        .ask(prompt_text)
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).to_i

      payload = response.content.is_a?(Hash) ? response.content : JSON.parse(response.content.to_s)

      complete_interaction(interaction, response:, payload:, elapsed_ms:) if interaction

      Result.new(
        verdict: payload.fetch("verdict"),
        confidence_score: payload.fetch("confidence_score").to_f.clamp(0, 0.97),
        reason_summary: payload.fetch("reason_summary")
      )
    rescue StandardError => e
      fail_interaction(interaction, e) if interaction
      raise
    end

    def create_interaction(investigation:, claim_assessment:, model:, prompt_text:, packet_fingerprint:)
      return nil unless investigation

      LlmInteraction.create!(
        investigation:,
        claim_assessment:,
        interaction_type: :assessment,
        model_id: model,
        prompt_text:,
        evidence_packet_fingerprint: packet_fingerprint,
        status: :pending
      )
    rescue StandardError => e
      Rails.logger.warn("Failed to create LLM interaction record: #{e.message}")
      nil
    end

    def complete_interaction(interaction, response:, payload:, elapsed_ms:)
      interaction.update!(
        response_text: response.content.to_s,
        response_json: payload,
        status: :completed,
        latency_ms: elapsed_ms,
        prompt_tokens: response.respond_to?(:input_tokens) ? response.input_tokens : nil,
        completion_tokens: response.respond_to?(:output_tokens) ? response.output_tokens : nil
      )
    rescue StandardError => e
      Rails.logger.warn("Failed to update LLM interaction record: #{e.message}")
    end

    def fail_interaction(interaction, error)
      interaction.update!(
        status: :failed,
        error_class: error.class.name,
        error_message: error.message.truncate(500)
      )
    rescue StandardError
      nil
    end

    def parse_response(json)
      Result.new(
        verdict: json.fetch("verdict"),
        confidence_score: json.fetch("confidence_score").to_f.clamp(0, 0.97),
        reason_summary: json.fetch("reason_summary")
      )
    end

    def build_prompt(claim:, evidence_packet:)
      {
        claim: claim.canonical_text,
        claim_kind: claim.claim_kind,
        checkability_status: claim.checkability_status,
        entities: claim.entities_json,
        time_scope: claim.time_scope,
        evidence_count: evidence_packet.size,
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
