# Stubs for OpenRouter LLM API calls and web search.
# Loaded by test_helper.rb to make all tests run without network access.
#
# Tests that need real LLM responses should use:
#   setup { WebMock.allow_net_connect! }
#   teardown { WebMock.disable_net_connect! }

require "webmock/minitest"

module LlmStubs
  OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

  # Stub Fetchers::WebSearcher to avoid Chromium launches in tests.
  # Returns a single fake search result.
  def self.stub_web_searcher!
    return if @web_searcher_stubbed

    Fetchers::WebSearcher.class_eval do
      alias_method :original_search_duckduckgo_via_chromium, :search_duckduckgo_via_chromium

      define_method(:search_duckduckgo_via_chromium) do
        [
          Fetchers::WebSearcher::SearchResult.new(
            url: "https://example.com/search-result",
            title: "Stubbed search result",
            snippet: "This is a stubbed search result for testing."
          )
        ]
      end
    end
    @web_searcher_stubbed = true
  end

  # Generic LLM response that works for all structured-output analyzers.
  # The response adapts based on the schema name in the request.
  def self.stub_openrouter!
    WebMock.stub_request(:post, OPENROUTER_URL)
      .to_return do |request|
        body = JSON.parse(request.body) rescue {}
        schema_name = extract_schema_name(body)
        response_content = build_response_for(schema_name)

        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "gen-#{SecureRandom.hex(8)}",
            model: body.dig("model") || "anthropic/claude-sonnet-4-6",
            choices: [ {
              message: {
                role: "assistant",
                content: response_content.to_json
              },
              finish_reason: "stop"
            } ],
            usage: { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 }
          }.to_json
        }
      end
  end

  # Stub the models endpoint that RubyLLM may call
  def self.stub_openrouter_models!
    WebMock.stub_request(:get, /openrouter\.ai\/api\/v1\/models/)
      .to_return(status: 200, body: { data: [] }.to_json, headers: { "Content-Type" => "application/json" })
  end

  private_class_method def self.extract_schema_name(body)
    # RubyLLM sends the schema in response_format or tools
    schema = body.dig("response_format", "json_schema", "name") ||
             body.dig("response_format", "schema", "name") ||
             body.dig("tools", 0, "function", "name")
    schema.to_s
  end

  private_class_method def self.build_response_for(schema_name)
    case schema_name
    when "rhetorical_analysis"
      { fallacies: [], narrative_bias_score: 0.15, summary: "Minor rhetorical patterns detected." }
    when "contextual_gap_analysis"
      { gaps: [ { question: "What context is missing?", relevance: "Important for full understanding", search_query: "missing context test" } ],
        completeness_score: 0.6, summary: "Some contextual gaps identified." }
    when "batch_content_analysis"
      {
        source_misrepresentation: { misrepresentations: [], misrepresentation_score: 0.0, summary: "Sources appear accurately represented." },
        temporal_manipulation: { manipulations: [], temporal_integrity_score: 0.9, summary: "No significant temporal issues." },
        statistical_deception: { deceptions: [], statistical_integrity_score: 1.0, summary: "No statistical deception detected." },
        selective_quotation: { quotations: [], quotation_integrity_score: 1.0, summary: "No selective quotation issues." },
        authority_laundering: { chains: [], laundering_score: 0.0, summary: "No authority laundering detected." }
      }
    when "narrative_fingerprint"
      { core_event: "A news event occurred", blamed_entities: [ "Entity A" ], defended_entities: [ "Entity B" ],
        emotional_anchors: [ "outrage" ], stance: "Critical of Entity A", key_omissions: [ "Missing context" ],
        meta_vs_substance: "balanced", search_queries: [ "test event coverage", "test event analysis" ] }
    when "narrative_comparison"
      { coordination_score: 0.3, pattern_summary: "Some editorial alignment detected.",
        convergent_framing: [ "Shared blame structure" ], convergent_omissions: [ "Missing counter-evidence" ] }
    when "emotional_analysis"
      { emotional_temperature: 0.4, evidence_density: 0.6, manipulation_score: 0.25,
        dominant_emotions: [ "concern" ], contributing_factors: [ { factor: "Moderate emotional language", weight: 0.3 } ],
        summary: "Moderate emotional content with reasonable evidence density." }
    when "investigation_summary"
      { conclusion: "The article presents a mixed quality assessment.", strengths: [ "Uses some credible sources" ],
        weaknesses: [ "Some context is missing" ], overall_quality: "mixed" }
    when "claim_assessment", "verdict"
      { verdict: "supported", confidence_score: 0.75, reason_summary: "Evidence supports this claim.",
        checkability_status: "checkable", missing_evidence: nil }
    when "search_queries"
      { queries: [ "test search query 1", "test search query 2" ] }
    when "claim_extraction"
      { claims: [ { text: "Test claim", kind: "statement", time_scope: nil, checkability: "checkable", reason: "Verifiable statement" } ] }
    when "claim_canonicalization"
      { canonical_text: "Test canonical claim", semantic_key: "test_claim", canonical_fingerprint: SecureRandom.hex(16) }
    when "claim_similarity"
      { is_equivalent: false, confidence: 0.3, explanation: "Claims are different" }
    when /source_misrepresentation/
      { misrepresentations: [], misrepresentation_score: 0.0, summary: "No misrepresentation detected." }
    when /temporal_manipulation/
      { manipulations: [], temporal_integrity_score: 1.0, summary: "No temporal manipulation detected." }
    when /statistical_deception/
      { deceptions: [], statistical_integrity_score: 1.0, summary: "No statistical deception detected." }
    when /selective_quotation/
      { quotations: [], quotation_integrity_score: 1.0, summary: "No selective quotation issues." }
    when /authority_laundering/
      { chains: [], laundering_score: 0.0, circular_citations_detected: 0, summary: "No authority laundering detected." }
    else
      # Generic safe response for any unknown schema
      { result: "ok", score: 0.5, summary: "Analysis complete." }
    end
  end
end
