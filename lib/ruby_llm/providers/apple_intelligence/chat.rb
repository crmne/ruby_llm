# frozen_string_literal: true

require 'open3'
require 'json'

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

          input_parts = conversation.map do |msg|
            "#{msg.role}: #{extract_text(msg.content)}"
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

          Message.new(
            role: :assistant,
            content: output_text,
            model_id: body['model'] || 'apple-intelligence',
            input_tokens: 0,
            output_tokens: estimated_tokens,
            raw: body
          )
        rescue JSON::ParserError => e
          raise RubyLLM::Error, "Failed to parse binary response: #{e.message}"
        end

        def estimate_tokens(text)
          (text.length / 4.0).ceil
        end
      end
    end
  end
end
