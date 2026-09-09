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
      protocol :voxtral_transcription, Bedrock::Mantle::Voxtral
      protocol :titan_text_embeddings, Protocols::InvokeModel::TitanTextEmbeddings,
               batches: Protocols::InvokeModel::EmbeddingBatches
      protocol :titan_multimodal_embeddings, Protocols::InvokeModel::TitanMultimodalEmbeddings,
               batches: Protocols::InvokeModel::EmbeddingBatches
      protocol :cohere_embeddings, Protocols::InvokeModel::CohereEmbeddings
      protocol :nova_embeddings, Protocols::InvokeModel::NovaEmbeddings
      protocol :stability_images, Protocols::InvokeModel::StabilityImages
      protocol :rerank, Protocols::Bedrock::Rerank
      protocol :guardrails, Protocols::Bedrock::Guardrails
      protocol :async_videos, Protocols::Bedrock::AsyncVideos
      protocol :files, Protocols::Bedrock::Files

      def self.capabilities
        Bedrock::Capabilities
      end

      def self.resolve_registry_id(model_id, models, config = RubyLLM.config)
        Models.resolve_registry_id(model_id, models, config)
      end

      def self.models_dev_alias(...)
        Models.models_dev_alias(...)
      end

      def protocol_for(model, operation: nil, **)
        return protocols[:guardrails] if operation == :moderate

        model_id = model_id_for(model)
        return embedding_protocol_for(model_id) if operation == :embed
        return image_protocol_for(model_id) if operation == :paint
        return protocols[:rerank] if operation == :rerank
        return video_protocol_for(model_id) if operation == :animate
        return protocols[:voxtral_transcription] if voxtral_transcription?(operation, model_id)
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
        @mantle_connection ||= Transport::Connection.new(self, @config, api_base: mantle_api_base)
      end

      def api_base
        @config.bedrock_api_base || "https://bedrock-runtime.#{bedrock_region}.amazonaws.com"
      end

      def control_api_base
        @config.bedrock_api_base || "https://bedrock.#{bedrock_region}.amazonaws.com"
      end

      def agent_api_base # :nodoc:
        @config.bedrock_api_base || "https://bedrock-agent-runtime.#{bedrock_region}.amazonaws.com"
      end

      def agent_connection # :nodoc:
        @agent_connection ||= Transport::Connection.new(self, @config, api_base: agent_api_base)
      end

      def rerank_model_arn(model_id) # :nodoc:
        return model_id if model_id.start_with?('arn:')

        unless %w[amazon.rerank-v1:0 cohere.rerank-v3-5:0].include?(model_id)
          raise Error, "Bedrock reranking is not supported for #{model_id.inspect}"
        end

        "arn:aws:bedrock:#{bedrock_region}::foundation-model/#{model_id}"
      end

      def headers
        {}
      end

      def guardrail_url # :nodoc:
        identifier = @config.bedrock_guardrail_id
        version = @config.bedrock_guardrail_version
        if identifier.to_s.empty? || version.to_s.empty?
          raise ConfigurationError, 'Bedrock moderation requires bedrock_guardrail_id and bedrock_guardrail_version'
        end

        identifier = URI.encode_www_form_component(identifier)
        version = URI.encode_www_form_component(version)
        "/guardrail/#{identifier}/version/#{version}/apply"
      end

      def batch_cost_multiplier(**) = 0.5

      def embedding_batch_protocol(model_id) # :nodoc:
        case model_id
        when 'amazon.titan-embed-text-v2:0' then protocols[:titan_text_embeddings]
        when 'amazon.titan-embed-image-v1' then protocols[:titan_multimodal_embeddings]
        end
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
            bedrock_video_s3_uri
            bedrock_guardrail_id
            bedrock_guardrail_version
          ]
        end

        def configuration_requirements
          %i[bedrock_region]
        end

        def model_required?(operation:)
          operation != :moderate
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

      def voxtral_transcription?(operation, model_id)
        operation == :transcribe && model_id == 'mistral.voxtral-small-24b-2507'
      end

      def batch_protocol_for(requests)
        return super unless requests.any? { |request| request.key?(:text) }

        kinds = requests.map { |request| embedding_batch_protocol(request.fetch(:model)) }.uniq
        unless requests.all? { |request| request.key?(:text) } && kinds.one? && kinds.first
          raise Error, 'Bedrock embedding batches require one supported Titan embedding model'
        end

        kinds.first
      end

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

      def image_protocol_for(model_id)
        base_id = model_id.sub(/\A(?:#{Protocols::Converse::REGION_PREFIXES.join('|')})\./, '')
        return protocols[:stability_images] if Protocols::InvokeModel::StabilityImages::MODELS.include?(base_id)

        raise Error, "Bedrock image generation is not supported for #{model_id.inspect}"
      end

      def video_protocol_for(model_id)
        return protocols[:async_videos] if model_id == 'luma.ray-v2:0'

        raise Error, "Bedrock video generation is not supported for #{model_id.inspect}"
      end

      def bedrock_model_id_pattern(prefix)
        /\A(?:(?:#{Protocols::Converse::REGION_PREFIXES.join('|')})\.)?#{Regexp.escape(prefix)}/
      end
    end
  end
end
