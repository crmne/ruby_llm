# frozen_string_literal: true

module RubyLLM
  # Base interface for LLM providers like OpenAI and Anthropic.
  # Handles the complexities of API communication, streaming responses,
  # and error handling so individual providers can focus on their unique features.
  module Provider
    # Common functionality for all LLM providers. Implements the core provider
    # interface so specific providers only need to implement a few key methods.
    module Methods
      extend Streaming

      def complete(messages, tools:, temperature:, model:, connection:, &)
        normalized_temperature = maybe_normalize_temperature(temperature, model)

        payload = render_payload(messages,
                                 tools: tools,
                                 temperature: normalized_temperature,
                                 model: model,
                                 stream: block_given?)

        if block_given?
          stream_response connection, payload, &
        else
          sync_response connection, payload
        end
      end

      def list_models(connection:)
        response = connection.get models_url
        parse_list_models_response response, slug, capabilities
      end

      def embed(text, model:, connection:, dimensions:)
        payload = render_embedding_payload(text, model:, dimensions:)
        response = connection.post(embedding_url(model:), payload)
        parse_embedding_response(response, model:)
      end

      def paint(prompt, model:, size:, connection:)
        payload = render_image_payload(prompt, model:, size:)
        response = connection.post images_url, payload
        parse_image_response(response, model:)
      end

      def configured?(config = nil)
        config ||= RubyLLM.config
        missing_configs(config).empty?
      end

      def missing_configs(config)
        configuration_requirements.select do |key|
          value = config.send(key)
          value.nil? || value.empty?
        end
      end

      def local?
        false
      end

      def remote?
        !local?
      end

      private

      def maybe_normalize_temperature(temperature, model)
        if capabilities.respond_to?(:normalize_temperature)
          capabilities.normalize_temperature(temperature, model)
        else
          temperature
        end
      end

      def sync_response(connection, payload)
        response = connection.post completion_url, payload
        parse_completion_response response
      end
    end

    def try_parse_json(maybe_json)
      return maybe_json unless maybe_json.is_a?(String)

      JSON.parse(maybe_json)
    rescue JSON::ParserError
      maybe_json
    end

    def parse_error(response)
      return if response.body.empty?

      body = try_parse_json(response.body)
      case body
      when Hash
        body.dig('error', 'message')
      when Array
        body.map do |part|
          part.dig('error', 'message')
        end.join('. ')
      else
        body
      end
    end

    def parse_data_uri(uri)
      if uri&.start_with?('data:')
        match = uri.match(/\Adata:([^;]+);base64,(.+)\z/)
        return { mime_type: match[1], data: match[2] } if match
      end

      # If it's not a data URI, return nil
      nil
    end

    def connection(config)
      @connection ||= Connection.new(self, config)
    end

    class << self
      def extended(base)
        base.extend(Methods)
        base.extend(Streaming)
      end

      def register(name, provider_module)
        providers[name.to_sym] = provider_module
      end

      def for(model)
        model_info = Models.find(model)
        providers[model_info.provider.to_sym]
      end

      def providers
        @providers ||= {}
      end

      def local_providers
        providers.select { |_slug, provider| provider.local? }
      end

      def remote_providers
        providers.select { |_slug, provider| provider.remote? }
      end

      def configured_providers(config = nil)
        providers.select { |_slug, provider| provider.configured?(config) }.values
      end
    end
  end
end
