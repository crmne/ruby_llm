# frozen_string_literal: true

module RubyLLM
  module Providers
    # AWS Bedrock integration.
    class Bedrock < Provider
      include Bedrock::Auth
      include Bedrock::Models

      protocol :converse, Protocols::Converse, batches: Protocols::Converse::Batches
      protocol :mantle_anthropic, Bedrock::Mantle::Anthropic
      protocol :mantle_responses, Bedrock::Mantle::Responses
      protocol :mantle_chat_completions, Bedrock::Mantle::ChatCompletions
      protocol :titan_text_embeddings, Protocols::InvokeModel::TitanTextEmbeddings
      protocol :titan_multimodal_embeddings, Protocols::InvokeModel::TitanMultimodalEmbeddings
      protocol :cohere_embeddings, Protocols::InvokeModel::CohereEmbeddings
      protocol :nova_embeddings, Protocols::InvokeModel::NovaEmbeddings
      protocol :files, Protocols::Bedrock::Files

      def self.resolve_registry_id(model_id, models, config = RubyLLM.config)
        Models.resolve_registry_id(model_id, models, config)
      end

      def self.models_dev_alias(...)
        Models.models_dev_alias(...)
      end

      def protocol_for(model, operation: nil, **)
        model_id = model_id_for(model)
        return embedding_protocol_for(model_id) if operation == :embed
        return mantle_protocol_for(model_id) if mantle_model?(model_id)

        super
      end

      # Un-versioned ids such as anthropic.claude-sonnet-5 and
      # openai.gpt-oss-20b are served by the bedrock-mantle endpoint rather
      # than by Converse.
      def mantle_model?(model_id)
        Models.mantle_model?(model_id, RubyLLM.models)
      end

      def mantle_api_base
        @config.bedrock_mantle_api_base || "https://bedrock-mantle.#{bedrock_region}.api.aws"
      end

      def mantle_connection
        @mantle_connection ||= Connection.new(self, @config, api_base: mantle_api_base)
      end

      def api_base
        @config.bedrock_api_base || "https://bedrock-runtime.#{bedrock_region}.amazonaws.com"
      end

      def control_api_base
        @config.bedrock_api_base || "https://bedrock.#{bedrock_region}.amazonaws.com"
      end

      def headers
        {}
      end

      def parse_error(response)
        body = parse_error_body(response)
        return unless body
        return super unless body.is_a?(Hash)

        body['message'] || body['Message'] || nested_error_message(body) || body['__type'] || super
      end

      # bedrock-mantle nests code, message, and type under "error" rather
      # than answering with a bare string.
      def nested_error_message(body)
        error = body['error']
        error.is_a?(Hash) ? error['message'] || error : error
      end

      def list_models
        merge_mantle_models(list_converse_models, list_mantle_models)
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
            bedrock_mantle_api_base
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

      def list_converse_models
        parse_list_models_response(signed_get(models_api_base, models_url), slug, profile_ids: inference_profile_ids)
      end

      def list_mantle_models
        response = signed_get(mantle_api_base, mantle_models_url, service: Bedrock::Mantle::SIGNING_SERVICE)
        parse_mantle_models_response(response, slug)
      end

      def mantle_protocol_for(model_id)
        return protocols[:mantle_anthropic] if model_id.start_with?('anthropic.')
        return protocols[:mantle_responses] if Bedrock::Mantle::RESPONSES_MODELS.include?(model_id)

        protocols[:mantle_chat_completions]
      end

      def embedding_protocol_for(model_id)
        case model_id
        when bedrock_model_id_pattern('amazon.titan-embed-image')
          protocols[:titan_multimodal_embeddings]
        when bedrock_model_id_pattern('amazon.titan-embed-g1-text'),
             bedrock_model_id_pattern('amazon.titan-embed-text')
          protocols[:titan_text_embeddings]
        when bedrock_model_id_pattern('cohere.embed')
          protocols[:cohere_embeddings]
        when bedrock_model_id_pattern('amazon.nova-2-multimodal-embeddings')
          protocols[:nova_embeddings]
        else
          raise Error, "Bedrock embeddings are not supported for #{model_id.inspect}"
        end
      end

      def bedrock_model_id_pattern(prefix)
        /\A(?:(?:#{Protocols::Converse::REGION_PREFIXES.join('|')})\.)?#{Regexp.escape(prefix)}/
      end
    end
  end
end
