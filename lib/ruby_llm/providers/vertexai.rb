# frozen_string_literal: true

module RubyLLM
  module Providers
    # Google Vertex AI implementation
    class VertexAI < Gemini
      include VertexAI::Chat
      include VertexAI::Streaming
      include VertexAI::Embeddings
      include VertexAI::Models
      include VertexAI::Transcription

      def initialize(config)
        super
        @authorizer = nil
      end

      def api_base
        "https://#{@config.vertexai_location}-aiplatform.googleapis.com/v1beta1"
      end

      def headers
        if defined?(VCR) && !VCR.current_cassette.recording?
          { 'Authorization' => 'Bearer test-token' }
        else
          initialize_authorizer unless @authorizer
          @authorizer.apply({})
        end
      rescue Google::Auth::AuthorizationError => e
        raise UnauthorizedError.new(nil, "Invalid Google Cloud credentials for Vertex AI: #{e.message}")
      end

      class << self
        def configuration_requirements
          %i[vertexai_project_id vertexai_location]
        end
      end

      private

      def initialize_authorizer
        require 'googleauth'
        @authorizer = ::Google::Auth.get_application_default(
          scope: [
            'https://www.googleapis.com/auth/cloud-platform',
            'https://www.googleapis.com/auth/generative-language.retriever'
          ]
        )
      rescue LoadError
        raise Error,
              'The googleauth gem ~> 1.15 is required for Vertex AI. Please add it to your Gemfile: gem "googleauth"'
      end
    end
  end
end
