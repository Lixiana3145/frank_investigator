if defined?(RubyLLM)
  RubyLLM.configure do |config|
    config.openrouter_api_key = ENV["OPENROUTER_API_KEY"] if ENV["OPENROUTER_API_KEY"].present?
  end
end
