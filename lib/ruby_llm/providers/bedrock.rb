# frozen_string_literal: true

module RubyLLM
  module Providers
    # AWS Bedrock integration.
    class Bedrock < Provider
      include Bedrock::Auth
      include Bedrock::Models

      protocol :converse, Protocols::Converse

      def api_base
        @config.bedrock_api_base || "https://bedrock-runtime.#{bedrock_region}.amazonaws.com"
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

      def list_models
        response = signed_get(models_api_base, models_url)
        parse_list_models_response(response, slug, capabilities)
      end

      class << self
        def configuration_options
          %i[bedrock_api_key bedrock_secret_key bedrock_region bedrock_session_token bedrock_api_base]
        end

        def configuration_requirements
          %i[bedrock_api_key bedrock_secret_key bedrock_region]
        end
      end

      private

      def bedrock_region
        @config.bedrock_region
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
        Bedrock::Models.reasoning_embedded?(model)
      end
    end
  end
end
