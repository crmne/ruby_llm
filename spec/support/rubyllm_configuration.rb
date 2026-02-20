# frozen_string_literal: true

RubyLLM.configure do |config|
  config.model_registry_class = 'Model'
end

RSpec.shared_context 'with configured RubyLLM' do
  before do
    RubyLLM.configure do |config|
      config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', 'test')
      config.azure_api_base = ENV.fetch('AZURE_API_BASE', 'https://rubyllm.services.ai.azure.com/')
      config.azure_api_key = ENV.fetch('AZURE_API_KEY', 'test')
      config.bedrock_api_key = ENV.fetch('AWS_ACCESS_KEY_ID', 'test')
      config.bedrock_region = 'us-west-2'
      config.bedrock_secret_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', 'test')
      config.bedrock_session_token = ENV.fetch('AWS_SESSION_TOKEN', nil)
      config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', 'test')
      config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', 'test')
      config.gpustack_api_base = ENV.fetch('GPUSTACK_API_BASE', 'http://localhost:11444/v1')
      config.gpustack_api_key = ENV.fetch('GPUSTACK_API_KEY', nil)
      # Keep retries short in tests to avoid long backoff sleeps.
      config.max_retries = 2
      config.mistral_api_key = ENV.fetch('MISTRAL_API_KEY', 'test')
      config.model_registry_class = 'Model'
      config.ollama_api_base = ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434/v1')
      config.openai_api_key = ENV.fetch('OPENAI_API_KEY', 'test')
      config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', 'test')
      config.perplexity_api_key = ENV.fetch('PERPLEXITY_API_KEY', 'test')
      config.request_timeout = 600
      config.retry_backoff_factor = 0.1
      config.retry_interval = 0.01
      config.retry_interval_randomness = 0.01
      config.vertexai_location = ENV.fetch('GOOGLE_CLOUD_LOCATION', 'global')
      config.vertexai_project_id = ENV.fetch('GOOGLE_CLOUD_PROJECT', 'test-project')
      config.xai_api_key = ENV.fetch('XAI_API_KEY', 'test')
    end
  end
end
