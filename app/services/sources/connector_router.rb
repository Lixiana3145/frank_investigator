module Sources
  class ConnectorRouter
    def self.call(url:, host:, title:, html:, source_kind:, authority_tier:, authority_score:)
      new(url:, host:, title:, html:, source_kind:, authority_tier:, authority_score:).call
    end

    def initialize(url:, host:, title:, html:, source_kind:, authority_tier:, authority_score:)
      @url = url
      @host = host
      @title = title
      @html = html
      @source_kind = source_kind.to_sym
      @authority_tier = authority_tier.to_sym
      @authority_score = authority_score.to_f
    end

    def call
      connector.extract
    end

    private

    def connector
      case @source_kind
      when :government_record then Connectors::GovernmentRecordConnector.new(url: @url, host: @host, title: @title, html: @html)
      when :scientific_paper then Connectors::ScientificPaperConnector.new(url: @url, host: @host, title: @title, html: @html)
      when :company_filing then Connectors::CompanyFilingConnector.new(url: @url, host: @host, title: @title, html: @html)
      when :press_release then Connectors::PressReleaseConnector.new(url: @url, host: @host, title: @title, html: @html)
      else
        Connectors::NewsArticleConnector.new(
          url: @url,
          host: @host,
          title: @title,
          html: @html,
          source_kind: @source_kind,
          authority_tier: @authority_tier,
          authority_score: @authority_score
        )
      end
    end
  end
end
