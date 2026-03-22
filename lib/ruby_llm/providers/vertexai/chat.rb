# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Chat methods for the Vertex AI implementation
      module Chat
        def render_payload(...)
          payload = super
          payload[:contents] = normalize_tool_response_roles(payload[:contents])
          payload
        end

        def completion_url
          "projects/#{@config.vertexai_project_id}/locations/#{@config.vertexai_location}/publishers/google/models/#{@model}:generateContent" # rubocop:disable Layout/LineLength
        end

        private

        def normalize_tool_response_roles(contents)
          Array(contents).map do |content|
            next content unless tool_response_content?(content)

            content.merge(role: 'user')
          end
        end

        def tool_response_content?(content)
          content[:role] == 'function' && Array(content[:parts]).any? do |part|
            part[:functionResponse]
          end
        end
      end
    end
  end
end
