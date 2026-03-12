module Llm
  class FakeClient
    Result = Struct.new(:verdict, :confidence_score, :reason_summary, :model_results, :disagreement_details, :unanimous, keyword_init: true)

    class << self
      attr_accessor :next_result
    end

    def available?
      self.class.next_result.present?
    end

    def call(claim:, evidence_packet:, investigation: nil, claim_assessment: nil)
      self.class.next_result || Result.new(
        verdict: "needs_more_evidence",
        confidence_score: 0.41,
        reason_summary: "Fake client placeholder response."
      )
    end

    def call_batch(items:, investigation: nil)
      result = self.class.next_result || Result.new(
        verdict: "needs_more_evidence",
        confidence_score: 0.41,
        reason_summary: "Fake client batch placeholder response."
      )

      items.each_with_object({}) do |item, hash|
        hash[item[:claim].id] = result
      end
    end
  end
end
