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
      files VertexAI::Files

      SCOPES = [
        'https://www.googleapis.com/auth/cloud-platform',
        'https://www.googleapis.com/auth/generative-language.retriever'
      ].freeze

      # Vertex AI hosts models from several publishers, each speaking its
      # native protocol. Publisher-prefixed ids are MaaS models served
      # through the OpenAI-compatible endpoint.
      def protocol_for(model, **)
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

      def api_base
        return @config.vertexai_api_base if @config.vertexai_api_base

        if @config.vertexai_location.to_s == 'global'
          'https://aiplatform.googleapis.com/v1beta1'
        else
          "https://#{@config.vertexai_location}-aiplatform.googleapis.com/v1beta1"
        end
      end

      def headers
        initialize_authorizer unless @authorizer
        @authorizer.apply({})
      rescue Google::Auth::AuthorizationError => e
        raise UnauthorizedError.new(nil, "Invalid Google Cloud credentials for Vertex AI: #{e.message}")
      end

      class << self
        def configuration_options
          %i[
            vertexai_project_id
            vertexai_location
            vertexai_service_account_key
            vertexai_api_base
            vertexai_batch_gcs_uri
          ]
        end

        def configuration_requirements
          %i[vertexai_project_id vertexai_location]
        end
      end

      private

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
