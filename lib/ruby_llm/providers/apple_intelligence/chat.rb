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

        def build_payload(messages)
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

          latest_user_message = extract_text(conversation.pop.content) if conversation.last&.role == :user

          # After tool execution, the last message is :tool (the result).
          # Build a prompt that asks the model to answer using the tool result.
          if latest_user_message.nil? || latest_user_message.empty?
            tool_results = conversation.select { |m| m.role == :tool }.map { |m| extract_text(m.content) }
            user_msg = conversation.select { |m| m.role == :user }.last
            original_question = user_msg ? extract_text(user_msg.content) : 'the user question'

            latest_user_message = "Answer this question: #{original_question}\n\nUse this data: #{tool_results.join('; ')}"
            conversation = [] # already incorporated into the prompt
          end

          input_parts = conversation.map do |msg|
            format_conversation_message(msg)
          end

          payload = {
            prompt: latest_user_message,
            model: 'on-device',
            format: 'json',
            stream: false
          }
          payload[:system] = system_prompt if system_prompt
          payload[:input] = input_parts.join("\n") unless input_parts.empty?
          payload
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

        def execute_binary(payload, config, tools: nil)
          bin = BinaryManager.binary_path(config)
          json_input = JSON.generate(payload)

          stdout, stderr, status = Open3.capture3(bin, stdin_data: json_input)

          handle_exit_code(status, stdout, stderr)
          parse_binary_response(stdout)
        end

        # Two-pass tool calling: first ask the model to extract arguments,
        # then construct the tool call programmatically.
        def resolve_tool_call(tools, user_message, config)
          return nil unless tools&.any?

          tool_name, tool = tools.first # single-tool shortcut for now

          # Zero-parameter tools: call immediately
          if tool.parameters.empty?
            call_id = "call_#{SecureRandom.hex(8)}"
            return { call_id => ToolCall.new(id: call_id, name: tool_name.to_s, arguments: {}) }
          end

          # Build a minimal extraction prompt per parameter
          arguments = {}
          bin = BinaryManager.binary_path(config)

          tool.parameters.each_value do |param|
            prompt = "What #{param.name} is mentioned in this text? Reply with just the value, nothing else.\n\n#{user_message}"
            payload = { prompt: prompt, model: 'on-device', format: 'json', stream: false }

            stdout, _stderr, status = Open3.capture3(bin, stdin_data: JSON.generate(payload))
            next unless status.success?

            body = JSON.parse(stdout) rescue next
            next unless body['ok']

            raw_output = (body['output'] || '').strip
            # The model might wrap the answer in JSON or return plain text
            value = begin
              parsed = JSON.parse(raw_output)
              # If it returned {"city": "Tokyo"} or {"value": "Tokyo"}
              parsed.is_a?(Hash) ? (parsed[param.name.to_s] || parsed.values.first) : parsed.to_s
            rescue JSON::ParserError
              raw_output.gsub(/\A["']|["']\z/, '') # strip quotes if plain text
            end

            arguments[param.name.to_sym] = value if value && !value.empty?
          end

          return nil if arguments.empty?

          call_id = "call_#{SecureRandom.hex(8)}"
          { call_id => ToolCall.new(id: call_id, name: tool_name.to_s, arguments: arguments) }
        rescue StandardError => e
          RubyLLM.logger.debug { "Tool call resolution failed: #{e.message}" }
          nil
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
