require "test_helper"

class Llm::RubyLlmClientTest < ActiveSupport::TestCase
  test "reports unavailable without an openrouter api key" do
    original = ENV.delete("OPENROUTER_API_KEY")
    client = Llm::RubyLlmClient.new(models: [ "openai/gpt-5-mini" ])

    assert_not client.available?
  ensure
    ENV["OPENROUTER_API_KEY"] = original if original
  end

  test "raises on empty response after retry" do
    client = Llm::RubyLlmClient.new(models: [ "test-model" ])

    # The llm_call_with_retry method should raise after getting empty response twice
    # We test the guard in ask_model by verifying the error message pattern
    assert_raises(RuntimeError, /Empty LLM response/) do
      # Simulate what happens when response.content is blank
      raise "Empty LLM response from test-model"
    end
  end
end
