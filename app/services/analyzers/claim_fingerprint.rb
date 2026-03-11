module Analyzers
  class ClaimFingerprint
    def self.call(text)
      text.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").squish
    end
  end
end
