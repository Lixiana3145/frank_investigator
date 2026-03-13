module Analyzers
  class ClaimNoiseFilter
    UI_BOILERPLATE_PATTERNS = [
      /\bcookie/i,
      /\bconsent/i,
      /\baceitar\b/i,
      /\bnewsletter\b/i,
      /\binscreva-se\b/i,
      /\bsubscri(?:be|ption)\b/i,
      /\bsign\s+(?:in|up|out)\b/i,
      /\blog\s*(?:in|out)\b/i,
      /\bentrar\b.*\bcadast/i,
      /\bcompartilh(?:ar|e)\b.*\b(?:facebook|twitter|whatsapp)\b/i,
      /\bshare\s+(?:on|this)\b/i,
      /\bbaixe?\s+(?:o\s+)?app\b/i,
      /\bdownload\s+(?:the\s+)?app\b/i,
      /\bleia\s+(?:tamb[eé]m|mais)\b/i,           # "Leia também" / "Leia mais"
      /\bveja\s+(?:tamb[eé]m|mais)\b/i,            # "Veja também"
      /\bsaiba\s+mais\b/i,                          # "Saiba mais"
      /\bclique\s+(?:aqui|para)\b/i,                # "Clique aqui"
      /\bcontinue\s+lendo\b/i,                      # "Continue lendo"
      /\bread\s+more\b/i,
      /\bassine\s/i,                                 # "Assine" (subscribe)
      /\bassinante\b/i,                              # "Assinante" (subscriber)
      /\bconteúdo\s+exclusivo\b/i,                   # "Conteúdo exclusivo" (exclusive content)
      /\bacesse\s+(?:já|agora)\b/i                   # "Acesse já" (access now)
    ].freeze

    METADATA_PATTERNS = [
      /\A(?:por|by)\s+[A-Z][a-záéíóúãõç]+\s+[A-Z]/i,
      /\batualizado\s+(?:há|em)\b/i,
      /\bupdated?\s+(?:on|at)\b/i,
      /\AArticle metadata:/i,
      /\A\d{1,2}\/\d{1,2}\/\d{2,4}\z/,
      /\A\d{1,2}\s+(?:de\s+)?(?:jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)/i,
      /\A(?:publicado|published)\s+/i,
      /\A(?:foto|image|crédito|credit|ilustração):/i,
      /\ARedação\b/i,                                 # "Redação" (editorial team)
      /\A[A-Z][a-záéíóúãõç]+\s+[A-Z][a-záéíóúãõç]+\s*[-–—]\s*\d/  # "Nome Sobrenome - 10/03/2026"
    ].freeze

    PORTAL_BOILERPLATE = [
      "Fala.BR",
      "Plataforma Integrada",
      "Ouvidoria e Acesso à Informação",
      "Plataforma Integrada de Ouvidoria",
      "Todos os direitos reservados",
      "All rights reserved",
      "Reprodução proibida",
      "Política de Privacidade"
    ].freeze

    NAVIGATION_PATTERNS = [
      /\A(?:Home|Início|Principal)\s*[>›»]/i,       # Breadcrumb
      /\A(?:Editorias?|Seções?|Cadernos?):/i,        # Section labels
      /\A(?:Mais|More)\s+(?:notícias|lidas|news)/i   # "Mais notícias"
    ].freeze

    def self.noise?(text)
      new(text).noise?
    end

    def initialize(text)
      @text = text.to_s.squish
    end

    def noise?
      return true if ui_boilerplate?
      return true if metadata?
      return true if portal_boilerplate?
      return true if navigation?
      return true if concatenated_headlines?
      return true if fragment_too_short?
      false
    end

    private

    def ui_boilerplate?
      UI_BOILERPLATE_PATTERNS.any? { |p| @text.match?(p) }
    end

    def metadata?
      METADATA_PATTERNS.any? { |p| @text.match?(p) }
    end

    def portal_boilerplate?
      PORTAL_BOILERPLATE.any? { |phrase| @text.include?(phrase) }
    end

    def navigation?
      NAVIGATION_PATTERNS.any? { |p| @text.match?(p) }
    end

    def concatenated_headlines?
      segments = @text.split(/\s{2,}|\t|\s*\|\s*/).reject(&:blank?)
      return false if segments.size < 3

      capitalized = segments.count { |s| s.match?(/\A[A-ZÁÉÍÓÚÃÕÇ]/) }
      no_period = segments.none? { |s| s.match?(/[.!?]\z/) }
      capitalized >= 3 && no_period
    end

    def fragment_too_short?
      return false if @text.length >= 40
      !@text.match?(/\b(?:is|are|was|were|has|have|had|will|would|could|should|can|do|does|did|said|says|announced|confirmed|reported|é|são|foi|foram|tem|teve|será|pode|deve|disse|afirmou|anunciou|confirmou)\b/i)
    end
  end
end
