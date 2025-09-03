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

          RubyLLM.logger.debug "Bedrock API Response Status: #{response.status}" if RubyLLM.config.log_stream_debug
          RubyLLM.logger.debug "Bedrock API Response Headers: #{response.headers}" if RubyLLM.config.log_stream_debug
          RubyLLM.logger.debug "Bedrock API Response Body: #{response.body}" if RubyLLM.config.log_stream_debug

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
            content: format_content_for_converse(msg.content)
          }
        end

        def format_content_for_converse(content)
          return [format_text_content(content)] unless content.is_a?(RubyLLM::Content)

          parts = []
          parts << format_text_content(content.text) if content.text

          content.attachments.each do |attachment|
            case attachment.type
            when :image
              parts << format_image_for_converse(attachment)
            when :pdf
              parts << format_document_for_converse(attachment)
            when :text
              parts << format_text_file_for_converse(attachment)
            else
              raise RubyLLM::UnsupportedAttachmentError, attachment.type
            end
          end

          parts
        end

        def format_text_content(text)
          { 'text' => text.to_s }
        end

        def format_image_for_converse(image)
          {
            'image' => {
              'format' => extract_image_format(image.mime_type),
              'name' => sanitize_filename(image.filename) || 'uploaded_image',
              'source' => { 'bytes' => image.encoded }
            }
          }
        end

        def format_document_for_converse(document)
          {
            'document' => {
              'format' => document.mime_type == 'application/pdf' ? 'pdf' : 'text',
              'name' => sanitize_filename(document.filename) || 'uploaded_document',
              'source' => { 'bytes' => document.encoded }
            }
          }
        end

        def format_text_file_for_converse(text_file)
          {
            'document' => {
              'format' => 'text',
              'name' => sanitize_filename(text_file.filename) || 'uploaded_text',
              'source' => { 'bytes' => text_file.encoded }
            }
          }
        end

        # Sanitizes filenames according to Bedrock's requirements:
        # - Only alphanumeric characters, whitespace, hyphens, parentheses, and square brackets
        # - No more than one consecutive whitespace character
        def sanitize_filename(filename)
          return nil unless filename

          # Remove any characters that aren't alphanumeric, whitespace, hyphens, parentheses, or square brackets
          sanitized = filename.gsub(/[^a-zA-Z0-9\s\-()\[\]]/, '')

          # Replace multiple consecutive whitespace characters with a single space
          sanitized = sanitized.gsub(/\s+/, ' ')

          # Trim leading and trailing whitespace
          sanitized = sanitized.strip

          # Return nil if the filename is empty after sanitization
          sanitized.empty? ? nil : sanitized
        end

        # Extracts the image format from MIME type for Bedrock's image format field
        # Bedrock supports: gif, jpeg, png, webp
        def extract_image_format(mime_type)
          case mime_type
          when 'image/png'
            'png'
          when 'image/jpeg', 'image/jpg'
            'jpeg'
          when 'image/gif'
            'gif'
          when 'image/webp'
            'webp'
          else
            # Default to png for unknown formats
            RubyLLM.logger.warn "Unknown image MIME type: #{mime_type}, defaulting to png"
            'png'
          end
        end

        def format_tool_call(msg)
          # Get the first tool call from the hash
          tool_call = msg.tool_calls.values.first

          if tool_call.nil?
            RubyLLM.logger.warn 'Bedrock: tool_call is nil for tool call message'
            return nil
          end

          if RubyLLM.config.log_stream_debug
            RubyLLM.logger.debug "Formatting tool call message: #{msg.inspect}"
            RubyLLM.logger.debug "Tool call: #{tool_call.inspect}"
            RubyLLM.logger.debug "Tool call ID: #{tool_call.id}"
          end

          # Ensure we have a valid tool call ID
          if tool_call.id.nil? || tool_call.id.empty?
            RubyLLM.logger.warn 'Bedrock: tool_call.id is null or empty for tool call message'
            return nil
          end

          result = {
            role: convert_role(msg.role),
            content: [
              {
                'toolUse' => {
                  'toolUseId' => tool_call.id,
                  'name' => tool_call.name,
                  'input' => tool_call.arguments
                }
              }
            ]
          }

          RubyLLM.logger.debug "Formatted tool call: #{result}" if RubyLLM.config.log_stream_debug

          result
        end

        def format_tool_result(msg)
          # Debug logging to understand the issue
          if RubyLLM.config.log_stream_debug
            RubyLLM.logger.debug "Formatting tool result message: #{msg.inspect}"
            RubyLLM.logger.debug "Tool call ID: #{msg.tool_call_id}"
            RubyLLM.logger.debug "Message role: #{msg.role}"
            RubyLLM.logger.debug "Message content: #{msg.content}"
          end

          # Ensure we have a valid tool_call_id
          tool_call_id = msg.tool_call_id
          if tool_call_id.nil? || tool_call_id.empty?
            RubyLLM.logger.warn 'Bedrock: tool_call_id is null or empty for tool result message'
            # Try to extract from the message content or other sources
            # For now, we'll skip this message to avoid the validation error
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

          RubyLLM.logger.debug "Bedrock output: #{output}" if RubyLLM.config.log_stream_debug
          RubyLLM.logger.debug "Bedrock message: #{message}" if RubyLLM.config.log_stream_debug
          RubyLLM.logger.debug "Bedrock content_blocks: #{content_blocks}" if RubyLLM.config.log_stream_debug

          text_content = extract_text_content(content_blocks)
          tool_use_blocks = find_tool_uses(content_blocks)

          RubyLLM.logger.debug "Extracted text_content: #{text_content}" if RubyLLM.config.log_stream_debug
          RubyLLM.logger.debug "Extracted tool_use_blocks: #{tool_use_blocks}" if RubyLLM.config.log_stream_debug

          message_obj = build_message(data, text_content, tool_use_blocks, response)
          RubyLLM.logger.debug "Built message object: #{message_obj.inspect}" if RubyLLM.config.log_stream_debug

          message_obj
        end

        def extract_text_content(blocks)
          text_blocks = blocks.select { |c| c['text'] }
          text_blocks.map { |c| c['text'] }.join
        end

        def find_tool_uses(blocks)
          blocks.select { |c| c['toolUse'] }
        end

        def parse_tool_calls(tool_use_blocks)
          tool_use_blocks.map do |block|
            tool_use = block['toolUse']
            RubyLLM::ToolCall.new(
              id: tool_use['id'],
              name: tool_use['name'],
              arguments: tool_use['input']
            )
          end
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
            RubyLLM.logger.debug "Built message: role=#{message.role}, content=#{message.content}, tool_calls=#{message.tool_calls}, input_tokens=#{message.input_tokens}, output_tokens=#{message.output_tokens}"
          end

          message
        end

        def extract_token_usage(data)
          # Extract token usage from the response data
          # The converse endpoint should return token usage in the same format as streaming metadata events
          if data['usage']
            input_tokens = data['usage']['inputTokens']
            output_tokens = data['usage']['outputTokens']

            if input_tokens && output_tokens
              if RubyLLM.config.log_stream_debug
                RubyLLM.logger.debug "Found token usage in response: input=#{input_tokens}, output=#{output_tokens}"
              end
              return { input_tokens: input_tokens, output_tokens: output_tokens }
            end
          end

          # No token usage found
          RubyLLM.logger.warn 'Bedrock: No token usage information found in response'
          RubyLLM.logger.debug "Response data keys: #{data.keys}" if RubyLLM.config.log_stream_debug
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

          payload = build_base_payload(chat_messages, model).tap do |p|
            add_optional_fields(p, system_content:, tools:, temperature:)
          end

          if RubyLLM.config.log_stream_debug
            RubyLLM.logger.debug 'Final Bedrock payload:'
            RubyLLM.logger.debug JSON.pretty_generate(payload)
          end

          payload
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
          if RubyLLM.config.log_stream_debug
            RubyLLM.logger.debug "Building base payload with #{chat_messages.length} messages"
            chat_messages.each_with_index do |msg, index|
              RubyLLM.logger.debug "Message #{index}: role=#{msg.role}, tool_call?=#{msg.tool_call?}, tool_result?=#{msg.tool_result?}, tool_call_id=#{msg.tool_call_id}"
            end
          end

          formatted_messages = chat_messages.map { |msg| format_message(msg) }

          if RubyLLM.config.log_stream_debug
            RubyLLM.logger.debug "Formatted messages: #{formatted_messages.length} messages"
            formatted_messages.each_with_index do |msg, index|
              RubyLLM.logger.debug "Formatted message #{index}: #{msg.inspect}"
            end
          end

          compacted_messages = formatted_messages.compact

          if RubyLLM.config.log_stream_debug
            RubyLLM.logger.debug "Compacted messages: #{compacted_messages.length} messages"
            compacted_messages.each_with_index do |msg, index|
              RubyLLM.logger.debug "Compacted message #{index}: #{msg.inspect}"
            end
          end

          # Validate that no message contains both toolUse and toolResult
          compacted_messages.each_with_index do |message, index|
            next unless message && message[:content]

            has_tool_use = message[:content].any? { |content| content['toolUse'] }
            has_tool_result = message[:content].any? { |content| content['toolResult'] }

            next unless has_tool_use && has_tool_result

            RubyLLM.logger.error "Bedrock validation error: Message #{index} contains both toolUse and toolResult"
            RubyLLM.logger.error "Message content: #{message[:content]}"
            raise 'Bedrock validation error: Message cannot contain both toolUse and toolResult'
          end

          {
            messages: compacted_messages,
            inferenceConfig: {
              maxTokens: model.max_tokens || 4096
            }
          }
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
            tools: tools.values.map { |t| function_for(t) },
            toolChoice: { auto: {} }
          }
        end

        def function_for(tool)
          {
            toolSpec: {
              name: tool.name,
              description: tool.description,
              inputSchema: {
                json: {
                  type: 'object',
                  properties: tool.parameters.transform_values { |param| param_schema(param) },
                  required: tool.parameters.select { |_, p| p.required }.keys
                }
              }
            }
          }
        end

        def param_schema(param)
          {
            type: param.type,
            description: param.description
          }.compact
        end
      end
    end
  end
end
