require "test_helper"

class Llm::RubyLlmClientTest < ActiveSupport::TestCase
  test "reports unavailable without an openrouter api key" do
    original = ENV.delete("OPENROUTER_API_KEY")
    client = Llm::RubyLlmClient.new(models: [ "openai/gpt-5-mini" ])

    assert_not client.available?
  ensure
    ENV["OPENROUTER_API_KEY"] = original if original
  end
end
