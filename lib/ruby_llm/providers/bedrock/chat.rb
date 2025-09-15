# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Chat methods for the AWS Bedrock API implementation
      module Chat
        module_function

        def sync_response(connection, payload, additional_headers = {})
          signature = sign_request("#{connection.connection.url_prefix}#{completion_url}", payload:)
          response = connection.post completion_url, payload do |req|
            req.headers.merge! build_headers(signature.headers, streaming: block_given?)
            req.headers = additional_headers.merge(req.headers) unless additional_headers.empty?
          end

          parse_completion_response response
        end

        def format_message(msg)
          if msg.tool_call?
            result = format_tool_call(msg)
            # If format_tool_call returns nil (due to missing tool_call), skip this message
            return nil if result.nil?

            result
          elsif msg.tool_result?
            result = format_tool_result(msg)
            # If format_tool_result returns nil (due to missing tool_call_id), skip this message
            return nil if result.nil?

            result
          else
            format_basic_message(msg)
          end
        end

        def format_basic_message(msg)
          {
            role: convert_role(msg.role),
            content: Media.format_content_for_converse(msg.content)
          }
        end

        def format_tool_call(msg)
          tool_calls = msg.tool_calls.values.compact

          if tool_calls.empty?
            RubyLLM.logger.warn 'Bedrock: tool_calls empty for tool call message'
            return nil
          end

          content_blocks = tool_calls.filter_map do |tc|
            next if tc.id.nil? || tc.id.empty?

            { 'toolUse' => { 'toolUseId' => tc.id, 'name' => tc.name, 'input' => tc.arguments } }
          end

          if content_blocks.empty?
            RubyLLM.logger.warn 'Bedrock: all tool_calls had missing ids; skipping tool call message'
            return nil
          end

          result = { role: convert_role(msg.role), content: content_blocks }

          RubyLLM.logger.debug "Formatted tool call: #{result}" if RubyLLM.config.log_stream_debug

          result
        end

        def format_tool_result(msg)
          tool_call_id = msg.tool_call_id
          if tool_call_id.nil? || tool_call_id.empty?
            RubyLLM.logger.warn 'Bedrock: tool_call_id is null or empty for tool result message'

            return nil
          end

          result = {
            role: convert_role(msg.role),
            content: [
              {
                'toolResult' => {
                  'toolUseId' => tool_call_id,
                  'content' => [{ 'text' => msg.content }]
                }
              }
            ]
          }

          RubyLLM.logger.debug "Formatted tool result: #{result}" if RubyLLM.config.log_stream_debug

          result
        end

        def convert_role(role)
          case role
          when :system, :user, :tool then 'user'
          else 'assistant'
          end
        end

        def parse_completion_response(response)
          data = response.body
          RubyLLM.logger.debug "Parsing Bedrock response data: #{data}" if RubyLLM.config.log_stream_debug

          output = data['output'] || {}
          message = output['message'] || {}
          content_blocks = message['content'] || []
          text_content = extract_text_content(content_blocks)
          tool_use_blocks = find_tool_uses(content_blocks)

          build_message(data, text_content, tool_use_blocks, response)
        end

        def extract_text_content(blocks)
          text_blocks = blocks.select { |c| c['text'] }
          text_blocks.map { |c| c['text'] }.join
        end

        def find_tool_uses(blocks)
          blocks.select { |c| c['toolUse'] }
        end

        # Delegate to Bedrock::Tools for consistency with OpenAI provider naming
        def parse_tool_calls(tool_use_blocks)
          Tools.parse_tool_calls(tool_use_blocks)
        end

        def build_message(data, content, tool_use_blocks, response)
          # Extract token usage from the response
          # For the converse endpoint, token usage should be in data['usage'] similar to streaming metadata events
          usage = extract_token_usage(data)
          RubyLLM.logger.debug "Building message with usage: #{usage}" if RubyLLM.config.log_stream_debug

          # Validate required fields
          if content.nil?
            RubyLLM.logger.warn 'Bedrock: content is nil, setting to empty string'
            content = ''
          end

          if @model_id.nil?
            RubyLLM.logger.warn 'Bedrock: model_id is nil'
            @model_id = 'unknown'
          end

          # Parse tool calls safely
          tool_calls = []
          begin
            tool_calls = parse_tool_calls(tool_use_blocks)
          rescue StandardError => e
            RubyLLM.logger.warn "Bedrock: Failed to parse tool calls: #{e.message}"
            tool_calls = []
          end

          message = RubyLLM::Message.new(
            role: :assistant,
            content: content,
            tool_calls: tool_calls,
            input_tokens: usage[:input_tokens],
            output_tokens: usage[:output_tokens],
            model_id: @model_id,
            raw: response
          )

          if RubyLLM.config.log_stream_debug
            RubyLLM.logger.debug(
              "Built message: role=#{message.role}, content=#{message.content}, tool_calls=#{message.tool_calls}, " \
              "input_tokens=#{message.input_tokens}, output_tokens=#{message.output_tokens}"
            )
          end

          message
        end

        def extract_token_usage(data)
          # Extract token usage from the response data
          # The converse endpoint should return token usage in the same format as streaming metadata events
          if data['usage']
            input_tokens = data['usage']['inputTokens']
            output_tokens = data['usage']['outputTokens']

            return { input_tokens: input_tokens, output_tokens: output_tokens } if input_tokens && output_tokens
          end

          # No token usage found
          { input_tokens: nil, output_tokens: nil }
        end

        private

        def completion_url
          "model/#{@model_id}/converse"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil) # rubocop:disable Lint/UnusedMethodArgument,Metrics/ParameterLists
          @model_id = model.id

          system_messages, chat_messages = separate_messages(messages)
          system_content = build_system_content(system_messages)

          build_base_payload(chat_messages, model).tap do |p|
            add_optional_fields(p, system_content:, tools:, temperature:)
          end
        end

        def separate_messages(messages)
          messages.partition { |msg| msg.role == :system }
        end

        def build_system_content(system_messages)
          if system_messages.length > 1
            RubyLLM.logger.warn(
              "Bedrock's converse implementation only supports a single system message. " \
              'Multiple system messages will be combined into one.'
            )
          end

          system_messages.map(&:content).join("\n\n")
        end

        def build_base_payload(chat_messages, model)
          compacted_messages = chat_messages.filter_map { |msg| format_message(msg) }
          compacted_messages = merge_consecutive_tool_result_messages(compacted_messages)
          validate_no_tool_use_and_result!(compacted_messages)

          {
            messages: compacted_messages,
            inferenceConfig: {
              maxTokens: model.max_tokens || 4096
            }
          }
        end

        def validate_no_tool_use_and_result!(messages)
          index = messages.find_index { |message| invalid_tool_content?(message) }
          return unless index

          RubyLLM.logger.error "Bedrock validation error: Message #{index} contains both toolUse and toolResult"
          RubyLLM.logger.error "Message content: #{messages[index][:content]}"
          raise 'Bedrock validation error: Message cannot contain both toolUse and toolResult'
        end

        def invalid_tool_content?(message)
          return false unless message && message[:content]

          content = message[:content]
          has_tool_use = content.any? { |c| c['toolUse'] }
          has_tool_result = content.any? { |c| c['toolResult'] }
          has_tool_use && has_tool_result
        end

        # Bedrock requires that if the assistant returns multiple toolUse blocks in a single turn,
        # the client responds with a single user message containing multiple toolResult blocks.
        # Merge consecutive toolResult-only messages into one to satisfy this requirement.
        def merge_consecutive_tool_result_messages(messages)
          merged = []
          index = 0

          while index < messages.length
            message = messages[index]
            if tool_result_only_message?(message)
              combined_content = []
              while index < messages.length && tool_result_only_message?(messages[index])
                combined_content.concat(messages[index][:content])
                index += 1
              end
              merged << { role: 'user', content: combined_content }
            else
              merged << message
              index += 1
            end
          end

          merged
        end

        def tool_result_only_message?(message)
          return false unless message && message[:content].is_a?(Array)

          message[:content].all? { |c| c['toolResult'] }
        end

        def add_optional_fields(payload, system_content:, tools:, temperature:)
          if system_content && !system_content.empty?
            # Add system message as the first user message
            payload[:messages].unshift({
                                         role: 'user',
                                         content: [{ 'text' => system_content }]
                                       })
          end

          payload[:inferenceConfig][:temperature] = temperature unless temperature.nil?

          return unless tools.any?

          payload[:toolConfig] = {
            tools: tools.values.map { |t| Tools.tool_for(t) },
            toolChoice: { auto: {} }
          }
        end
      end
    end
  end
end
