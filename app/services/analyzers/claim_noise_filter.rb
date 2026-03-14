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
      /\bcopiar\s+link\b/i,                            # "copiar link" (copy link)
      /\bcopy\s+link\b/i,
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
      /\bacesse\s+(?:já|agora)\b/i,                   # "Acesse já" (access now)
      /\bsubtitles?\s+settings?\b/i,                   # Video player UI
      /\bchapters?\s+descriptions?\b/i,                 # Video player UI
      /\bfullscreen\b/i,                                # Video player UI
      /\bplayback\s+(?:speed|rate)\b/i,                 # Video player UI
      /\blei\s+geral\s+de\s+prote[çc][ãa]o\s+de\s+dados\b/i, # LGPD privacy notice
      /\bprote[çc][ãa]o\s+de\s+dados\s+pessoais\b/i,   # Privacy notice
      /\bgeneral\s+data\s+protection\b/i                # GDPR privacy notice
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
      /\A[A-Z][a-záéíóúãõç]+\s+[A-Z][a-záéíóúãõç]+\s*[-–—]\s*\d/,  # "Nome Sobrenome - 10/03/2026"
      # Bylines without "Por" prefix: "Élida Oliveira 12/11/2025 05h00"
      /\A[A-Z][a-záéíóúãõç]+\s+[A-Z][a-záéíóúãõç]+\s+\d{1,2}\/\d{1,2}\/\d{2,4}/,
      # Bylines with time: "Nome Sobrenome 05h00" or "Nome 14:30"
      /\A[A-Z][a-záéíóúãõç]+(?:\s+[A-Z][a-záéíóúãõç]+){1,3}\s+\d{1,2}[h:]\d{2}/
    ].freeze

    PORTAL_BOILERPLATE = [
      "Fala.BR",
      "Plataforma Integrada",
      "Ouvidoria e Acesso à Informação",
      "Plataforma Integrada de Ouvidoria",
      "Todos os direitos reservados",
      "All rights reserved",
      "Reprodução proibida",
      "Política de Privacidade",
      "Publicidade",
      "Propaganda",
      "Advertisement"
    ].freeze

    PRICING_PATTERNS = [
      /R\$\s*\d+[.,]\d{2}/,                            # "R$ 49,90" or "R$1,90"
      /\b\d+[.,]\d{2}\s*\/\s*m[eê]s\b/i,               # "49,90/mês"
      /\btelevendas\b/i,
      /\bSAC\b.*\b\d{4}/,                               # "SAC Capitais: 4003-..."
      /\b0800\s+\d{3}\s+\d{4}\b/,                       # "0800 770 2166"
      /\bsorteio\b/i,                                    # "Detalhes do sorteio"
      /\bcartão\s+presente\b/i,                          # "cartão presente"
      /\bvoucher\b/i
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
      return true if pricing?
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

    def pricing?
      PRICING_PATTERNS.any? { |p| @text.match?(p) }
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
