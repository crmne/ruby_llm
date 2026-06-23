# frozen_string_literal: true

module RubyLLM
  module Providers
    # AWS Bedrock integration.
    class Bedrock < Provider
      include Bedrock::Auth
      include Bedrock::Embeddings
      include Bedrock::Models

      protocol :converse, Protocols::Converse, batches: Protocols::Converse::Batches
      files Bedrock::Files

      def api_base
        @config.bedrock_api_base || "https://bedrock-runtime.#{bedrock_region}.amazonaws.com"
      end

      def control_api_base
        @config.bedrock_api_base || "https://bedrock.#{bedrock_region}.amazonaws.com"
      end

      def headers
        {}
      end

      def complete(messages, model:, params: {}, **rest, &)
        super(messages, model:, params: normalize_params(params, model:), **rest, &)
      end

      def parse_error(response)
        return if response.body.nil? || response.body.empty?

        body = try_parse_json(response.body)
        return body if body.is_a?(String)

        body['message'] || body['Message'] || body['error'] || body['__type'] || super
      end

      def embed(text, model:, dimensions:)
        texts = [text].flatten
        url = embedding_url(model:)

        results = texts.map do |t|
          payload = render_embedding_payload(t, model:, dimensions:)
          body = JSON.generate(payload)
          signed_hdrs = sign_headers('POST', url, body)

          @connection.post(url, payload) do |req|
            req.headers.merge!(signed_hdrs)
          end
        end

        vectors = results.map { |r| r.body['embedding'] }
        input_tokens = results.sum { |r| r.body['inputTextTokenCount'] || 0 }
        vectors = vectors.first unless text.is_a?(Array)

        Embedding.new(vectors:, model:, input_tokens:)
      end

      def list_models
        response = signed_get(models_api_base, models_url)
        parse_list_models_response(response, slug, capabilities)
      end

      class << self
        def configuration_options
          %i[
            bedrock_api_key
            bedrock_secret_key
            bedrock_region
            bedrock_session_token
            bedrock_credential_provider
            bedrock_api_base
            bedrock_batch_s3_uri
            bedrock_batch_role_arn
          ]
        end

        def configuration_requirements
          %i[bedrock_region]
        end

        def configured?(config)
          !!(config.bedrock_region && credentials_configured?(config))
        end

        def credentials_configured?(config)
          return credential_provider?(config) if config.bedrock_credential_provider

          !!(config.bedrock_api_key && config.bedrock_secret_key)
        end

        private

        def credential_provider?(config)
          config.bedrock_credential_provider&.respond_to?(:credentials)
        end
      end

      def ensure_configured!
        return if configured?

        missing = []
        missing << :bedrock_region unless @config.bedrock_region
        missing << bedrock_credentials_requirement unless self.class.credentials_configured?(@config)

        raise ConfigurationError, "Missing configuration for Bedrock: #{missing.join(', ')}"
      end

      private

      def bedrock_region
        @config.bedrock_region
      end

      def bedrock_credentials_requirement
        if @config.bedrock_credential_provider
          'bedrock_credential_provider responding to #credentials'
        else
          'bedrock_credential_provider or bedrock_api_key + bedrock_secret_key'
        end
      end

      def normalize_params(params, model:)
        normalized = RubyLLM::Utils.deep_symbolize_keys(params || {})
        additional_fields = normalized[:additionalModelRequestFields] || {}

        top_k = normalized.delete(:top_k)
        if !top_k.nil? && model_supports_top_k?(model)
          additional_fields = RubyLLM::Utils.deep_merge(additional_fields, { top_k: top_k })
        end

        normalized[:additionalModelRequestFields] = additional_fields unless additional_fields.empty?
        normalized
      end

      def model_supports_top_k?(model)
        Protocols::Converse.reasoning_embedded?(model)
      end
    end
  end
end
