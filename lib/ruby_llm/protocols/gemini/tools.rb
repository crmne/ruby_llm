# frozen_string_literal: true

require 'rubygems/version'
require 'securerandom'

module RubyLLM
  module Protocols
    class Gemini
      # Tools methods for the Gemini API implementation
      module Tools
        MULTIMODAL_FUNCTION_RESPONSE_GENERATION = Gem::Version.new('3')

        def format_tools(tools)
          return [] if tools.empty?

          [{
            functionDeclarations: tools.values.map { |tool| function_declaration_for(tool) }
          }]
        end

        def format_tool_call(msg) # rubocop:disable Metrics/PerceivedComplexity
          parts = []

          parts.concat(Media.format_content(msg.content, msg.attachments)) if msg.content && !msg.content.empty?

          fallback_signature = msg.thinking&.signature
          used_fallback = false

          msg.tool_calls.each_value do |tool_call|
            part = {
              functionCall: {
                name: tool_call.name,
                args: tool_call.arguments
              }
            }

            signature = tool_call.thought_signature
            if signature.nil? && fallback_signature && !used_fallback
              signature = fallback_signature
              used_fallback = true
            end
            part[:thoughtSignature] = signature if signature
            parts << part
          end

          parts
        end

        def format_tool_result(msg, function_name = nil)
          function_name ||= msg.tool_call_id
          content = msg.content
          content = nil if content && content.empty?
          content = '(no output)' if content.nil? && msg.attachments.empty?

          function_response = {
            name: function_name,
            response: {
              name: function_name,
              content: Media.format_content(content)
            }
          }

          media_parts, sibling_parts = partition_tool_result_attachments(msg.attachments)
          function_response[:parts] = media_parts if media_parts.any?

          [{ functionResponse: function_response }, *sibling_parts]
        end

        def extract_tool_calls(data) # rubocop:disable Metrics/PerceivedComplexity
          return nil unless data

          candidate = data.is_a?(Hash) ? data.dig('candidates', 0) : nil
          return nil unless candidate

          parts = candidate.dig('content', 'parts')
          return nil unless parts.is_a?(Array)

          tool_calls = parts.each_with_object({}) do |part, result|
            function_data = part['functionCall']
            next unless function_data

            id = SecureRandom.uuid
            thought_signature = part['thoughtSignature'] || part['thought_signature']

            result[id] = ToolCall.new(
              id:,
              name: function_data['name'],
              arguments: function_data['args'] || {},
              thought_signature: thought_signature
            )
          end

          tool_calls.empty? ? nil : tool_calls
        end

        private

        # functionResponse.parts only accepts inline bytes, and pre-Gemini 3 models reject it
        def partition_tool_result_attachments(attachments)
          return [[], []] if attachments.empty?

          parts = attachments.map { |attachment| Media.format_content_attachment(attachment) }
          return [[], parts] unless multimodal_function_responses_supported?(@model)

          parts.partition { |part| part.key?(:inline_data) }
        end

        # Neither the model listing nor the registry distinguishes a Gemini
        # generation, so the id is the only signal available. The -latest
        # aliases always track the newest release.
        def multimodal_function_responses_supported?(model)
          id = model.respond_to?(:id) ? model.id.to_s : model.to_s
          return false unless id.start_with?('gemini-')
          return true if id.end_with?('-latest')

          generation = id[/\Agemini-(\d+(?:\.\d+)?)(?:-|\z)/, 1]
          generation ? Gem::Version.new(generation) >= MULTIMODAL_FUNCTION_RESPONSE_GENERATION : false
        end

        def function_declaration_for(tool)
          parameters_schema = tool.parameters_schema ||
                              RubyLLM::Tool::SchemaDefinition.from_parameters(tool.declared_parameters)&.json_schema

          declaration = {
            name: tool.name,
            description: tool.description
          }

          declaration[:parametersJsonSchema] = parameters_schema if parameters_schema

          return declaration if tool.provider_options.empty?

          RubyLLM::Utils.deep_merge(declaration, tool.provider_options)
        end

        def build_tool_config(tool_choice)
          {
            functionCallingConfig: {
              mode: forced_tool_choice?(tool_choice) ? 'any' : tool_choice
            }.tap do |config|
              # Use allowedFunctionNames to simulate specific tool choice
              config[:allowedFunctionNames] = [tool_choice] if specific_tool_choice?(tool_choice)
            end
          }
        end

        def forced_tool_choice?(tool_choice)
          tool_choice == :required || specific_tool_choice?(tool_choice)
        end

        def specific_tool_choice?(tool_choice)
          !%i[auto none required].include?(tool_choice)
        end
      end
    end
  end
end
