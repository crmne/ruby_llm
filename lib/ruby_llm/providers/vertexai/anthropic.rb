# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI < Provider
      # The Anthropic protocol over Vertex AI rawPredict endpoints.
      class Anthropic < Protocols::Anthropic
        ANTHROPIC_VERSION = 'vertex-2023-10-16'

        def completion_url
          "#{@provider.model_path(@model.id, publisher: 'anthropic')}:rawPredict"
        end

        def stream_url
          "#{@provider.model_path(@model.id, publisher: 'anthropic')}:streamRawPredict"
        end

        def render_payload(messages, **)
          payload = super
          payload.delete(:model)
          payload.merge(anthropic_version: ANTHROPIC_VERSION)
        end

        def supports_provider_file_references?
          false
        end
      end
    end
  end
end
