# frozen_string_literal: true

module RubyLLM
  module Providers
    module Mistral
      # Handles chat completions for Mistral models
      module Chat
        module_function

        def completion_url
          "#{Mistral.api_base(RubyLLM.config)}/chat/completions"
        end

        def stream_url
          completion_url
        end

        def render_payload(messages, tools:, temperature:, model:, stream: nil,
                           top_p: nil, max_tokens: nil, stop: nil, random_seed: nil, safe_prompt: nil,
                           response_format: nil, presence_penalty: nil, frequency_penalty: nil,
                           tool_choice: nil)
          # Ensure tools is always an array of tool objects (or nil)
          tools_array =
            if tools.nil?
              nil
            elsif tools.is_a?(Hash)
              tools.values
            else
              Array(tools)
            end

          effective_tool_choice = if tools_array&.any?
                                    # Tools are available, use provided choice or default to 'any' unless 'none' was forced
                                    tool_choice.nil? ? 'any' : tool_choice
                                  else
                                    # No tools available, tool_choice MUST be nil
                                    nil
                                  end

          payload = {
            model: model,
            messages: messages.map { |m| render_message(m) },
            temperature: temperature,
            stream: stream,
            tools: tools_array&.any? ? tools_array.map { |t| render_tool(t) } : nil,
            tool_choice: effective_tool_choice,
            top_p: top_p,
            max_tokens: max_tokens,
            stop: stop,
            random_seed: random_seed,
            safe_prompt: safe_prompt,
            response_format: response_format,
            presence_penalty: presence_penalty,
            frequency_penalty: frequency_penalty
          }.compact

          payload
        end

        def render_message(message)
          result = {}
          result[:role] = message.role

          # If the message content is a RubyLLM::Content with attachments, convert to multimodal array
          if message.content.is_a?(RubyLLM::Content)
            content = message.content
            if content.attachments.any?
              multimodal = []
              multimodal << { type: "text", text: content.text } if content.text
              content.attachments.each do |attachment|
                case attachment
                when RubyLLM::Attachments::Image
                  multimodal << { type: "image", source: attachment.url? ? { url: attachment.source } : { type: 'base64', media_type: attachment.mime_type, data: attachment.encoded } }
                # Add more attachment types if Mistral supports them
                end
              end
              # Always format multimodal for Mistral
              result[:content] = Mistral::Media.format_content(multimodal)
            else
              result[:content] = content.text
            end
          elsif message.content.is_a?(Array)
            # Multimodal content: format each part
            formatted_content = Mistral::Media.format_content(message.content.compact)
            result[:content] = formatted_content unless formatted_content.empty?
          else
            # Simple text content
            result[:content] = message.content
          end

          result[:tool_call_id] = message.tool_call_id if message.tool_call_id
          if message.role == :tool && message.respond_to?(:tool_name) && message.tool_name && !message.tool_name.to_s.empty?
            result[:name] = message.tool_name
          end
          if message.tool_calls&.any?
            tool_calls = message.tool_calls.is_a?(Hash) ? message.tool_calls.values : message.tool_calls
            result[:tool_calls] = tool_calls.map { |tc| render_tool_call(tc) }
          end
          result.compact
        end

        def render_tool_call(tool_call)
          tool_call_spec = {
            id: tool_call.id,
            type: 'function',
            function: {
              name: tool_call.name,
              arguments: tool_call.arguments
            }
          }
          tool_call_spec
        end

        def render_tool(tool)
          tool_spec = {
            type: 'function',
            function: {
              name: Tools.tool_call.name,
              description: tool.description,
              parameters: {
                type: 'object',
                properties: tool.parameters.transform_values do |param|
                  {
                    type: param.type,
                    description: param.description
                  }.compact
                end,
                required: tool.required_parameters.map(&:to_s)
              }
            }
          }
          tool_spec
        end

        def param_schema(param)
          {
            type: param.type,
            description: param.description
          }.compact
        end

        def parse_completion_response(response)
          if response.body['error']
            error_message = response.body.dig('error', 'message')
            error_message = error_message.sub(/^\s*{.*}\s*$/, 'Invalid message format')
            error_message = error_message.sub(/^[a-z]/, &:upcase)

            if error_message.include?('Input should be a valid')
              error_message = 'Invalid message format: The message content is not properly formatted'
            end

            raise Error.parse_error(response) || RubyLLM::Error.new(response, error_message)
          end

          choice = response.body.dig('choices', 0)
          return unless choice

          message = choice['message']
          return unless message

          tool_calls = Mistral::Tools.parse_tool_calls(message['tool_calls'])

          content = message['content']
          content = '' if content.nil? && tool_calls&.any?

          Message.new(
            role: message['role']&.to_sym,
            content: content,
            tool_calls: tool_calls,
            input_tokens: response.body.dig('usage', 'prompt_tokens'),
            output_tokens: response.body.dig('usage', 'completion_tokens'),
            model_id: response.body['model']
          )
        end

        def add_tool_result(tool_use_id, result)
          last_tool_call = messages.reverse.find { |m| m.role == :assistant && m.tool_calls }
          tool_name = last_tool_call&.tool_calls&.values&.find { |tc| tc.id == tool_use_id }&.name
          add_message(
            role: :tool,
            content: result.is_a?(Hash) && result[:error] ? result[:error] : result.to_s,
            tool_call_id: tool_use_id,
            name: tool_name
          )
        end

        def handle_tool_calls(chat_instance, response, &block)
          require 'ostruct'

          response.tool_calls.each_value do |tool_call|
            chat_instance.on_new_message&.call
            tool = chat_instance.tools[tool_call.name.to_sym]
            result = if tool.nil?
              { error: "Tool '#{tool_call.name}' is not available." }
            else
              args = tool_call.arguments
              tool.call(args)
            end
            tool_message = OpenStruct.new(
              role: :tool,
              content: result.is_a?(Hash) && result[:error] ? result[:error] : result.to_s,
              tool_call_id: tool_call.id,
              tool_name: tool_call.name,
              tool_calls: nil
            )
            chat_instance.on_end_message&.call(tool_message)

            last_user = chat_instance.messages.reverse.find { |m| m.role == :user }
            last_assistant = chat_instance.messages.reverse.find { |m| m.role == :assistant && m.tool_calls }
            pruned = [last_user, last_assistant, tool_message].compact

            chat_instance.messages.replace(pruned)

            return chat_instance.provider.complete(
              pruned,
              tools: chat_instance.tools,
              temperature: chat_instance.instance_variable_get(:@temperature),
              model: chat_instance.model.id,
              connection: chat_instance.instance_variable_get(:@connection),
              &block
            )
          end
        end

        # Refactored helper to prepare messages and tool_choice for API calls
        private def prepare_provider_call(messages, tools, opts)
          effective_messages = messages
          current_tool_choice = opts[:tool_choice]

          if messages.last&.role == :tool
            last_tool_result = messages.last
            assistant_call_index = messages.rindex { |m| m.role == :assistant && m.tool_calls&.values&.any? { |tc| tc.id == last_tool_result.tool_call_id } }

            if assistant_call_index
              last_assistant_call = messages[assistant_call_index]
              last_user_message = messages[0...assistant_call_index].reverse.find { |m| m.role == :user } || messages.find { |m| m.role == :user }
              pruned = [last_user_message, last_assistant_call, last_tool_result].compact
              effective_messages = pruned
              current_tool_choice = 'none'
            else
              RubyLLM.logger.warn "[MISTRAL WARN] Could not find matching assistant call for tool result #{last_tool_result.tool_call_id}. Sending full history."
              current_tool_choice ||= 'any' if tools&.any?
            end
          else
             current_tool_choice ||= 'any' if tools&.any?
          end

          [effective_messages, current_tool_choice]
        end

        def complete(messages, tools:, temperature:, model:, connection:, **opts, &block)
          # Check if block is given - if so, use streaming
          if block_given?
            return stream(messages, tools: tools, temperature: temperature, model: model, connection: connection, **opts, &block)
          end

          effective_messages, current_tool_choice = prepare_provider_call(messages, tools, opts)

          # Use 'effective_messages' and potentially overridden 'current_tool_choice'
          payload = render_payload(
            effective_messages,
            tools: tools,
            temperature: temperature,
            model: model,
            **opts.merge(tool_choice: current_tool_choice) # Merge potentially overridden tool_choice
          )
          response = connection.post(completion_url, payload)

          parsed_message = parse_completion_response(response)

          if parsed_message&.tool_call?
            registered_tool_names = tools.keys.map(&:to_sym)
            all_tool_calls = parsed_message.tool_calls
            valid_tool_calls = {}
            invalid_tool_calls = {}

            all_tool_calls.each do |tool_name_sym, tool_call|
              if registered_tool_names.include?(tool_name_sym)
                valid_tool_calls[tool_name_sym] = tool_call
              else
                RubyLLM.logger.warn "[MISTRAL WARN] Model requested unregistered tool: '#{tool_name_sym}'. Ignoring call."
                invalid_tool_calls[tool_name_sym] = tool_call
              end
            end

            if valid_tool_calls.any?
              parsed_message.instance_variable_set(:@tool_calls, valid_tool_calls)
            elsif invalid_tool_calls.any?
               if valid_tool_calls.empty?
                  parsed_message.instance_variable_set(:@tool_calls, nil)
                  first_invalid_tool_name = invalid_tool_calls.values.first&.name || "unknown tool"
                  parsed_message.instance_variable_set(:@content, "Error: Tool '#{first_invalid_tool_name}' is not available.")
               else
                  parsed_message.instance_variable_set(:@tool_calls, valid_tool_calls)
               end
            else
              parsed_message.instance_variable_set(:@tool_calls, nil)
            end
          end

          parsed_message
        end

        def stream(messages, tools:, temperature:, model:, connection:, **opts, &user_block)
          # Ensure Mistral::Streaming is available
          require_relative 'streaming' unless defined?(RubyLLM::Providers::Mistral::Streaming)

          # Generate payload with stream: true, no tool_choice forcing needed here
          effective_messages, current_tool_choice = prepare_provider_call(messages, tools, opts)
          
          payload = render_payload(
            effective_messages,
            tools: tools,
            temperature: temperature,
            model: model,
            stream: true,
            **opts.merge(tool_choice: current_tool_choice)
          )

          # Create accumulator to collect chunks for final message
          accumulator = StreamAccumulator.new
          buffer = String.new
          
          # Make POST request and process streaming response body directly
          response = connection.post(stream_url, payload) do |req|
             # Set headers for SSE
             req.headers['Accept'] = 'text/event-stream'
             req.headers['Cache-Control'] = 'no-cache'

             req.options.on_data = proc do |raw_chunk, _overall_received_bytes, _env|
                buffer << raw_chunk

                # Process buffer line by line for SSE events
                while (line_break = buffer.index("\n"))
                  line = buffer.slice!(0, line_break + 1).strip

                  if line.start_with?('data:')
                    data_json = line.delete_prefix('data:').strip

                    if data_json == '[DONE]'
                      buffer.clear # Clear buffer
                      # Potentially close the stream or signal completion if needed
                      next
                    end

                    begin
                      parsed_data = JSON.parse(data_json)                      
                      # Build chunk using provider's logic
                      chunk = Mistral::Streaming.build_chunk(parsed_data)                      
                      # Add to accumulator AND yield to user block
                      accumulator.add(chunk) if chunk
                      user_block.call(chunk) if chunk && user_block
                    rescue JSON::ParserError => e
                    end
                  else
                     RubyLLM.logger.warn "[MISTRAL STREAM WARN] Unexpected line format: #{line.inspect}"
                  end
                end # while line_break
             end # proc
          end # connection.post

          # Faraday post with on_data might return the response object, 
          # but check status *after* stream is potentially processed.
          # Error handling might be needed here if the stream fails early.
          unless response&.success?
             # Handle potential connection errors or non-200 status codes
             # ErrorMiddleware might have already handled this if it ran before on_data completed
             RubyLLM.logger.error "[MISTRAL STREAM ERROR] Request failed with status: #{response&.status}"
             # Consider raising an error based on response here if not handled by middleware
          end 
          
          # Return the accumulated message instead of nil
          accumulator.to_message
        end

        # Ensure the module includes the base streaming helpers
        include RubyLLM::Streaming

        public :complete, :stream
      end
    end
  end
end
