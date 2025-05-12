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
    # Provider-specific configuration
    attr_accessor :openai_api_key,
                  :openai_api_base,
                  :openai_organization_id,
                  :openai_project_id,
                  :anthropic_api_key,
                  :gemini_api_key,
                  :deepseek_api_key,
                  :bedrock_api_key,
                  :bedrock_secret_key,
                  :bedrock_region,
                  :bedrock_session_token,
                  :openrouter_api_key,
                  :ollama_api_base,
                  # Default models
                  :default_model,
                  :default_embedding_model,
                  :default_image_model,
                  # Connection configuration
                  :request_timeout,
                  :max_retries,
                  :retry_interval,
                  :retry_backoff_factor,
                  :retry_interval_randomness,
                  # Logging configuration
                  :log_file,
                  :log_level

    def initialize
      # Connection configuration
      @request_timeout = 120
      @max_retries = 3
      @retry_interval = 0.1
      @retry_backoff_factor = 2
      @retry_interval_randomness = 0.5

      # Default models
      @default_model = 'gpt-4.1-nano'
      @default_embedding_model = 'text-embedding-3-small'
      @default_image_model = 'dall-e-3'

      # Logging configuration
      @log_file = $stdout
      @log_level = ENV['RUBYLLM_DEBUG'] ? Logger::DEBUG : Logger::INFO
    end

    def inspect
      redacted = lambda do |name, value|
        if name.match?(/_id|_key|_secret|_token$/)
          value.nil? ? 'nil' : '[FILTERED]'
        else
          value
        end
      end

      inspection = instance_variables.map do |ivar|
        name = ivar.to_s.delete_prefix('@')
        value = redacted[name, instance_variable_get(ivar)]
        "#{name}: #{value}"
      end.join(', ')

      "#<#{self.class}:0x#{object_id.to_s(16)} #{inspection}>"
    end
  end
end
