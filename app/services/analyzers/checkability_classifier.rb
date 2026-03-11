module Analyzers
  class CheckabilityClassifier
    OPINION_PATTERNS = [
      /\bI think\b/i,
      /\bI believe\b/i,
      /\bopinion\b/i,
      /\bfeels like\b/i,
      /\bthe best\b/i,
      /\bthe worst\b/i
    ].freeze

    def self.call(text)
      sentence = text.to_s.squish
      return :ambiguous if sentence.blank? || sentence.end_with?("?")
      return :not_checkable if OPINION_PATTERNS.any? { |pattern| sentence.match?(pattern) }
      return :checkable if sentence.match?(/\b\d[\d,\.]*\b/) || sentence.match?(/\b(said|announced|reported|according to|confirmed|filed|approved)\b/i)
      return :checkable if sentence.match?(/\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+\b/)

      :ambiguous
    end
  end
end
