# frozen_string_literal: true

require 'stringio'

module RubyLLM
  module Providers
    # Google Vertex AI implementation
    class VertexAI < Provider
      protocol :gemini, VertexAI::Gemini, batches: VertexAI::Gemini::Batches
      protocol :anthropic, VertexAI::Anthropic, batches: VertexAI::Anthropic::Batches
      protocol :mistral, VertexAI::Mistral
      protocol :chat_completions, VertexAI::ChatCompletions, batches: VertexAI::ChatCompletions::Batches
      protocol :embed_content, VertexAI::EmbedContent
      protocol :embedding_prediction, Protocols::VertexAI::EmbeddingPrediction
      protocol :transcription, VertexAI::Transcription
      protocol :live_transcription, VertexAI::LiveTranscription
      protocol :ranking, Protocols::VertexAI::Ranking
      protocol :research, Protocols::VertexAI::Research
      protocol :files, Protocols::VertexAI::Files

      SCOPES = [
        'https://www.googleapis.com/auth/cloud-platform',
        'https://www.googleapis.com/auth/generative-language.retriever'
      ].freeze

      class << self
        def capabilities
          VertexAI::Capabilities
        end

        def models_dev_alias(...)
          VertexAI::Models.models_dev_alias(...)
        end

        # models.dev pins Vertex AI models to a version (claude-haiku-4-5@20251001);
        # Vertex AI serves them by bare name.
        def models_dev_model_id(id)
          id&.split('@')&.first
        end
      end

      # Vertex AI hosts models from several publishers, each speaking its
      # native protocol. Publisher-prefixed ids are MaaS models served
      # through the OpenAI-compatible endpoint.
      def protocol_for(model, operation: nil, **)
        return protocols[:ranking] if operation == :rerank

        transcription = transcription_protocol_for(model.id) if operation == :transcribe
        return transcription if transcription

        if operation == :embed && %w[gemini-embedding-2 gemini-embedding-2-preview].include?(model.id)
          return protocols[:embed_content]
        end

        case model.id
        when %r{/} then protocols[:chat_completions]
        when /\Aclaude/ then protocols[:anthropic]
        when VertexAI::Mistral::MODELS then protocols[:mistral]
        else super
        end
      end

      def location_path
        "projects/#{@config.vertexai_project_id}/locations/#{@config.vertexai_location}"
      end

      def model_path(model, publisher: 'google')
        "#{location_path}/publishers/#{publisher}/models/#{model}"
      end

      def initialize(config)
        super
        @authorizer = nil
      end

      def batch_protocol
        batch_protocol_for_name(:gemini)
      end

      def batch_protocol_for(requests)
        kinds = requests.map { |request| request.key?(:text) }.uniq
        raise Error, 'Vertex AI batches take chat or embedding requests, not both' unless kinds.size == 1
        return protocols[:embedding_prediction] if kinds.first

        models = requests.map { |request| request.fetch(:model) }.uniq
        raise Error, 'vertexai batch requests must use one model per submission' unless models.one?

        protocol_name = batch_protocol_name_for(models.first)
        protocol = batch_protocol_for_name(protocol_name)
        return protocol if protocol

        raise Error, 'vertexai batch requests currently support Gemini, Anthropic, and MaaS chat models'
      end
      private :batch_protocol, :batch_protocol_for

      def find_batch(id)
        batch = super
        protocol = batch_protocol_for_model_path(batch[:model])

        protocol ? batch.merge(batch_protocol: protocol) : batch
      end

      def batch_cost_multiplier(model:, component:)
        return if model.id.include?('/')
        return 1 if !model.id.start_with?('claude') && %i[cache_read cache_write].include?(component)

        0.5
      end

      def api_base
        api_base_for(@config.vertexai_location)
      end

      def api_base_for(location)
        return @config.vertexai_api_base if @config.vertexai_api_base

        if location.to_s == 'global'
          'https://aiplatform.googleapis.com/v1beta1'
        else
          "https://#{location}-aiplatform.googleapis.com/v1beta1"
        end
      end

      def ranking_config # :nodoc:
        @config.vertexai_ranking_config ||
          "projects/#{@config.vertexai_project_id}/locations/global/rankingConfigs/default_ranking_config"
      end

      def ranking_connection # :nodoc:
        base = @config.vertexai_ranking_api_base || 'https://discoveryengine.googleapis.com/v1'
        @ranking_connection ||= Transport::Connection.new(self, @config, api_base: base).tap do |connection|
          connection.connection.headers['X-Goog-User-Project'] = @config.vertexai_project_id
        end
      end

      # The rescue can't name Google::Auth::AuthorizationError directly:
      # when googleauth is missing, evaluating the constant would replace
      # the helpful install error with a NameError.
      def headers
        initialize_authorizer unless @authorizer
        @authorizer.apply({})
      rescue StandardError => e
        raise unless defined?(Google::Auth::AuthorizationError) && e.is_a?(Google::Auth::AuthorizationError)

        raise UnauthorizedError, "Invalid Google Cloud credentials for Vertex AI: #{e.message}"
      end

      class << self
        def configuration_options
          %i[
            vertexai_project_id
            vertexai_location
            vertexai_service_account_key
            vertexai_api_base
            vertexai_batch_gcs_uri
            vertexai_ranking_api_base
            vertexai_ranking_config
          ]
        end

        def configuration_requirements
          %i[vertexai_project_id vertexai_location]
        end
      end

      private

      def transcription_protocol_for(id)
        case id
        when 'gemini-3.5-transcribe-preview' then protocols[:transcription]
        when 'gemini-3.5-transcribe-live-preview' then protocols[:live_transcription]
        end
      end

      def initialize_authorizer
        require 'googleauth'
        @authorizer =
          if @config.vertexai_service_account_key
            ::Google::Auth::ServiceAccountCredentials.make_creds(
              json_key_io: StringIO.new(@config.vertexai_service_account_key),
              scope: SCOPES
            )
          else
            ::Google::Auth.get_application_default(SCOPES)
          end
      rescue LoadError
        raise Error,
              'The googleauth gem ~> 1.15 is required for Vertex AI. Please add it to your Gemfile: gem "googleauth"'
      end

      def batch_protocol_name_for(model)
        case model
        when %r{/} then :chat_completions
        when /\Aclaude/ then :anthropic
        when VertexAI::Mistral::MODELS then :mistral
        else :gemini
        end
      end

      def batch_protocol_for_model_path(model_path)
        if Protocols::VertexAI::EmbeddingPrediction::MODELS.include?(model_path.to_s.split('/').last)
          return protocols[:embedding_prediction]
        end

        case model_path.to_s
        when %r{/publishers/google/models/}, %r{\Apublishers/google/models/}
          batch_protocol_for_name(:gemini)
        when %r{/publishers/anthropic/models/}, %r{\Apublishers/anthropic/models/}
          batch_protocol_for_name(:anthropic)
        when %r{/publishers/mistralai/models/}, %r{\Apublishers/mistralai/models/}
          nil
        when %r{/publishers/[^/]+/models/}, %r{\Apublishers/[^/]+/models/}
          batch_protocol_for_name(:chat_completions)
        end
      end
    end
  end
end
