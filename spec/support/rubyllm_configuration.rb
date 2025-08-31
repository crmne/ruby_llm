# frozen_string_literal: true

RubyLLM.configure do |config|
  config.model_registry_class = 'Model'
end

RSpec.shared_context 'with configured RubyLLM' do
  before do
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch('OPENAI_API_KEY', 'test')
      config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', 'test')
      config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', 'test')
      config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', 'test')
      config.perplexity_api_key = ENV.fetch('PERPLEXITY_API_KEY', 'test')
      config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', 'test')
      config.mistral_api_key = ENV.fetch('MISTRAL_API_KEY', 'test')
      config.ollama_api_base = ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434/v1')

      config.gpustack_api_base = ENV.fetch('GPUSTACK_API_BASE', 'http://localhost:11444/v1')
      config.gpustack_api_key = ENV.fetch('GPUSTACK_API_KEY', nil)

      config.bedrock_api_key = ENV.fetch('AWS_ACCESS_KEY_ID', 'test')
      config.bedrock_secret_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', 'test')
      config.bedrock_region = 'us-west-2'
      config.bedrock_session_token = ENV.fetch('AWS_SESSION_TOKEN', nil)

      config.vertexai_project_id = ENV.fetch('GOOGLE_CLOUD_PROJECT', 'test-project')
      config.vertexai_location = ENV.fetch('GOOGLE_CLOUD_LOCATION', 'us-central1')

      config.request_timeout = 240
      config.max_retries = 10
      config.retry_interval = 1
      config.retry_backoff_factor = 3
      config.retry_interval_randomness = 0.5

      config.model_registry_class = 'Model'
    end
  end
end
