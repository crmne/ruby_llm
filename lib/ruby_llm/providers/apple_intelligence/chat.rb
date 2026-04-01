# frozen_string_literal: true

require 'open3'
require 'json'
require 'securerandom'

module RubyLLM
  module Providers
    class AppleIntelligence
      # Chat completion via the osx-ai-inloop binary pipe
      module Chat
        EXIT_CODE_ERRORS = {
          1 => 'Invalid arguments',
          2 => 'Unsupported environment',
          3 => 'Unavailable model',
          4 => 'Generation failure',
          5 => 'Internal error'
        }.freeze

        private

        def build_payload(messages, tools: nil)
          system_prompt = nil
          conversation = []
          latest_user_message = nil

          messages.each do |msg|
            case msg.role
            when :system
              system_prompt = extract_text(msg.content)
            when :user, :assistant, :tool
              conversation << msg
            end
          end

          system_prompt = append_tool_definitions(system_prompt, tools) if tools&.any?

          latest_user_message = extract_text(conversation.pop.content) if conversation.last&.role == :user

          input_parts = conversation.map do |msg|
            format_conversation_message(msg)
          end

          payload = {
            prompt: latest_user_message || '',
            model: 'on-device',
            format: 'json',
            stream: false
          }
          payload[:system] = system_prompt if system_prompt
          payload[:input] = input_parts.join("\n") unless input_parts.empty?
          payload
        end

        def append_tool_definitions(system_prompt, tools)
          tool_text = "You have access to the following tools:\n"

          tools.each_value do |tool|
            tool_text += "\nTool: #{tool.name}\n"
            tool_text += "Description: #{tool.description}\n"

            if tool.parameters.any?
              tool_text += "Parameters:\n"
              tool.parameters.each_value do |param|
                required_label = param.required ? 'required' : 'optional'
                tool_text += "  - #{param.name} (#{param.type}, #{required_label})"
                tool_text += ": #{param.description}" if param.description
                tool_text += "\n"
              end
            end
          end

          tool_text += <<~INSTRUCTIONS

            When you need to use a tool, respond with ONLY this exact JSON format, nothing else:
            {"tool_call": {"name": "tool_name", "arguments": {"param1": "value1"}}}

            If you don't need a tool, respond normally with plain text.
          INSTRUCTIONS

          [system_prompt, tool_text].compact.join("\n\n")
        end

        def format_conversation_message(msg)
          if msg.role == :tool
            tool_name = msg.tool_call_id || 'unknown'
            "tool_result (#{tool_name}): #{extract_text(msg.content)}"
          else
            "#{msg.role}: #{extract_text(msg.content)}"
          end
        end

        def extract_text(content)
          case content
          when String then content
          when Content then content.text || content.to_s
          else content.to_s
          end
        end

        def execute_binary(payload, config)
          bin = BinaryManager.binary_path(config)
          json_input = JSON.generate(payload)

          stdout, stderr, status = Open3.capture3(bin, stdin_data: json_input)

          handle_exit_code(status, stdout, stderr)
          parse_binary_response(stdout)
        end

        def handle_exit_code(status, stdout, stderr)
          return if status.success?

          code = status.exitstatus
          error_msg = EXIT_CODE_ERRORS[code] || "Unknown error (exit code #{code})"

          begin
            body = JSON.parse(stdout)
            if body['error']
              error_msg = "#{body['error']['code']}: #{body['error']['message']}"
            end
          rescue JSON::ParserError
            error_msg = "#{error_msg} — #{stderr}" unless stderr.empty?
          end

          case code
          when 1 then raise RubyLLM::BadRequestError, error_msg
          when 2 then raise RubyLLM::Error, "Unsupported environment: #{error_msg}"
          when 3 then raise RubyLLM::ModelNotFoundError, error_msg
          when 4 then raise RubyLLM::ServerError, error_msg
          when 5 then raise RubyLLM::ServerError, error_msg
          else        raise RubyLLM::Error, error_msg
          end
        end

        def parse_binary_response(stdout)
          body = JSON.parse(stdout)

          unless body['ok']
            error = body['error'] || {}
            raise RubyLLM::Error, "#{error['code']}: #{error['message']}"
          end

          output_text = body['output'] || ''
          estimated_tokens = estimate_tokens(output_text)
          model_id = body['model'] || 'apple-intelligence'

          tool_calls = extract_tool_calls(output_text)

          Message.new(
            role: :assistant,
            content: tool_calls ? '' : output_text,
            tool_calls: tool_calls,
            model_id: model_id,
            input_tokens: 0,
            output_tokens: estimated_tokens,
            raw: body
          )
        rescue JSON::ParserError => e
          raise RubyLLM::Error, "Failed to parse binary response: #{e.message}"
        end

        def extract_tool_calls(text)
          parsed = JSON.parse(text.strip)
          return nil unless parsed.is_a?(Hash) && parsed['tool_call']

          tc = parsed['tool_call']
          return nil unless tc['name']

          call_id = "call_#{SecureRandom.hex(8)}"
          arguments = (tc['arguments'] || {}).transform_keys(&:to_sym)

          { call_id => ToolCall.new(id: call_id, name: tc['name'], arguments: arguments) }
        rescue JSON::ParserError
          nil
        end

        def estimate_tokens(text)
          (text.length / 4.0).ceil
        end
      end
    end
  end
end
