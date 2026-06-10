# frozen_string_literal: true

require 'stringio'

module RubyLLM
  module Providers
    # Google Vertex AI implementation
    class VertexAI < Gemini
      include VertexAI::Embeddings
      include VertexAI::Models

      SCOPES = [
        'https://www.googleapis.com/auth/cloud-platform',
        'https://www.googleapis.com/auth/generative-language.retriever'
      ].freeze

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

      def completion_url
        "#{model_path(@model)}:generateContent"
      end

      def stream_url
        "#{model_path(@model)}:streamGenerateContent?alt=sse"
      end

      def headers
        initialize_authorizer unless @authorizer
        @authorizer.apply({})
      rescue Google::Auth::AuthorizationError => e
        raise UnauthorizedError.new(nil, "Invalid Google Cloud credentials for Vertex AI: #{e.message}")
      end

      class << self
        def configuration_options
          %i[vertexai_project_id vertexai_location vertexai_service_account_key vertexai_api_base]
        end

        def configuration_requirements
          %i[vertexai_project_id vertexai_location]
        end
      end

      private

      def model_path(model)
        "projects/#{@config.vertexai_project_id}/locations/#{@config.vertexai_location}" \
          "/publishers/google/models/#{model}"
      end

      def transcription_url(model)
        "#{model_path(model)}:generateContent"
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
    end
  end
end
