# frozen_string_literal: true

module RubyLLM
  # Global configuration for RubyLLM. Manages API keys, default models,
  # and provider-specific settings.
  #
  # Configure via:
  #   RubyLLM.configure do |config|
  #     config.openai_api_key = ENV['OPENAI_API_KEY']
  #     config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  #   end
  class Configuration
    attr_accessor :openai_api_key,
                  :anthropic_api_key,
                  :gemini_api_key,
                  :deepseek_api_key,
                  :bedrock_api_key,
                  :bedrock_secret_key,
                  :bedrock_region,
                  :bedrock_session_token,
                  :default_model,
                  :default_embedding_model,
                  :default_image_model,
                  :request_timeout,
                  :max_retries

    def initialize
      @request_timeout = 120
      @max_retries = 3
      @default_model = 'gpt-4o-mini'
      @default_embedding_model = 'text-embedding-3-small'
      @default_image_model = 'dall-e-3'
    end
  end
end
