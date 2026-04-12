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

    EVALUATIVE_QUALITY_PATTERNS = [
      /\b(?:good|great|bad|terrible|awful|excellent|competent|incompetent|effective|ineffective|successful|failed|lousy|strong|weak)\b/i,
      /\b(?:bom|boa|ruim|terr[ií]vel|horr[ií]vel|excelente|competente|incompetente|eficiente|ineficiente|bem-sucedid[oa]|fracassad[oa]|p[ée]ssim[oa]|forte|fraco)\b/i
    ].freeze

    COPULA_PATTERNS = [
      /\b(?:is|was|were|am|be|been|being|has been|have been|became|become)\b/i,
      /\b(?:[ée]|foi|era|foram|ser[aá]|tem sido|virou|ficou)\b/i
    ].freeze

    PUBLIC_ROLE_PATTERNS = [
      /\b(?:minister|ministry|president|presidency|administration|government|governor|mayor|senator|leader|cabinet|chancellor|prime minister)\b/i,
      /\b(?:ministro|ministra|minist[eé]rio|presidente|presid[eê]ncia|governo|governador|prefeit[oa]|senador|deputad[oa]|gest[aã]o|mandato|equipe econ[oô]mica)\b/i
    ].freeze

    PERSON_NAME_PATTERN = /\b[A-ZÀ-Ý][a-zà-ÿ]{2,}(?:\s+[A-ZÀ-Ý][a-zà-ÿ]{2,})+\b/

    def self.call(text)
      sentence = text.to_s.squish
      return :ambiguous if sentence.blank? || sentence.end_with?("?")
      return :not_checkable if opinion_like?(sentence)
      return :checkable if sentence.match?(/\b\d[\d,\.]*\b/) || sentence.match?(/\b(said|announced|reported|according to|confirmed|filed|approved)\b/i)
      return :checkable if sentence.match?(/\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+\b/)

      :ambiguous
    end

    def self.opinion_like?(sentence)
      OPINION_PATTERNS.any? { |pattern| sentence.match?(pattern) } || evaluative_performance_claim?(sentence)
    end

    def self.evaluative_performance_claim?(sentence)
      return false unless EVALUATIVE_QUALITY_PATTERNS.any? { |pattern| sentence.match?(pattern) }
      return false unless COPULA_PATTERNS.any? { |pattern| sentence.match?(pattern) }

      PUBLIC_ROLE_PATTERNS.any? { |pattern| sentence.match?(pattern) } || sentence.match?(PERSON_NAME_PATTERN)
    end
  end
end
