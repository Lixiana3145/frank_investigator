module Llm
  class ClientFactory
    def self.build
      Rails.application.config.x.frank_investigator.llm_client_class.constantize.new
    end
  end
end
