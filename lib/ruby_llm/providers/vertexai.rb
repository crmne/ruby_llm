# frozen_string_literal: true

require 'stringio'

module RubyLLM
  module Providers
    # Google Vertex AI implementation
    class VertexAI < Provider
      protocol :gemini, VertexAI::Gemini
      protocol :anthropic, VertexAI::Anthropic
      protocol :mistral, VertexAI::Mistral
      protocol :chat_completions, VertexAI::ChatCompletions
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
    end
  end
end
