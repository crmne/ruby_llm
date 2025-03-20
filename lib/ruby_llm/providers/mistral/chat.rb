module RubyLLM
  module Providers
    module Mistral
      # Handles chat completions for Mistral models
      module Chat
        module_function

        def completion_url
          "#{Mistral.api_base}/chat/completions"
        end

        def stream_url
          completion_url
        end

        def render_payload(messages, tools:, temperature:, model:, stream: nil)
          tools_array = if tools.nil?
              nil
            elsif tools.is_a?(Hash)
              tools.values
            else
              Array(tools)
            end

          # Ensure messages are properly processed to handle nil values
          processed_messages = messages.map { |m| render_message(m) }

          # Use the debugging helper for vision models to diagnose image issues
          if supports_vision?(model)
            debug_image_handling(messages, processed_messages)
          end

          # Debug any nil values in content arrays for vision models
          if ENV["DEBUG"] && supports_vision?(model)
            processed_messages.each_with_index do |msg, idx|
              if msg[:content].is_a?(Array) && msg[:content].any?(&:nil?)
                RubyLLM.logger.debug "WARNING: Nil values detected in content array for message #{idx}"
                RubyLLM.logger.debug "Original content before processing: #{messages[idx].content.inspect}"
                RubyLLM.logger.debug "Processed content: #{msg[:content].inspect}"
              end
            end
          end

          payload = {
            model: model,
            messages: processed_messages,
            temperature: temperature,
            stream: stream,
            tools: tools_array&.any? ? tools_array.map { |t| render_tool(t) } : nil,
            tool_choice: tools_array&.any? ? "any" : nil,
          }.compact

          # Debug information
          puts "Mistral payload: #{payload.inspect}" if ENV["DEBUG"]

          payload
        end

        def render_message(message)
          result = {}

          # Handle role
          result[:role] = message.role

          # Handle content (text or multimodal)
          if message.content.nil?
            # If content is nil, provide a simple empty message
            result[:content] = ""
          elsif message.content.is_a?(Array)
            # Log detailed information for debugging
            RubyLLM.logger.debug "Processing array content in message: #{message.content.inspect}" if ENV["DEBUG"]

            # Filter out any nil values and ensure the array is not empty
            filtered_content = message.content.compact
            if filtered_content.empty?
              # If the content array is empty after filtering, use a simple text content
              result[:content] = "Please describe what you see."
            else
              result[:content] = format_multimodal_content(filtered_content)
            end
          else
            result[:content] = message.content
          end

          # Handle tool calls
          if message.tool_calls&.any?
            tool_calls = message.tool_calls.is_a?(Hash) ? message.tool_calls.values : message.tool_calls
            result[:tool_calls] = tool_calls.map { |tc| render_tool_call(tc) }
          end

          # Add tool_call_id if present
          result[:tool_call_id] = message.tool_call_id if message.tool_call_id

          # For messages from tools, add the name field as required by Mistral API
          if message.role == :tool && message.tool_call_id
            # For Mistral, we need to provide a name for tool messages
            # Since we don't have access to the original tool name through the message,
            # we'll use a generic "tool" name as required by the Mistral API
            result[:name] = "tool"
          end

          result.compact
        end

        def format_multimodal_content(content)
          RubyLLM.logger.debug "Formatting multimodal content: #{content.inspect}"

          # NOTE: There's a known issue with vision models (e.g., Pixtral) where the content array
          # contains nil values, indicating that images aren't being properly attached or formatted.
          # The debug output typically shows: [{type: "text", text: "..."}, nil]
          # This is likely an issue with how the Content class handles image attachments for Mistral.
          # As a workaround, we filter out nil values below, but this doesn't solve the root issue
          # which requires changes to the core library's Content handling.

          # Filter out nil values and perform additional validation
          filtered_content = content.compact

          if filtered_content.empty?
            RubyLLM.logger.warn "WARNING: All items in the content array were nil or empty"
            # Return a simple text message to avoid API errors
            return [{ type: "text", text: "Please provide content for this message." }]
          end

          # Filter out any malformed image items (those without required data)
          validated_content = filtered_content.map do |item|
            if item.is_a?(Hash) && item[:type] == "image"
              if item[:url].nil? && (item[:data].nil? || item[:data].empty?)
                RubyLLM.logger.warn "WARNING: Skipping malformed image item: #{item.inspect}"
                nil
              else
                format_image_content(item)
              end
            else
              item
            end
          end.compact

          RubyLLM.logger.debug "Validated multimodal content: #{validated_content.inspect}"

          # If all content was filtered out, provide a fallback
          if validated_content.empty?
            RubyLLM.logger.warn "WARNING: All content was filtered out due to validation"
            [{ type: "text", text: "Please provide valid content for this message." }]
          else
            validated_content
          end
        end

        def format_image_content(image)
          # Format image according to Mistral's vision API requirements
          #
          # Mistral expects images in the following format:
          # {
          #   type: "image",
          #   source: {
          #     type: "url" | "base64",
          #     url: "https://example.com/image.jpg", # if type is "url"
          #     media_type: "image/jpeg", # if type is "base64"
          #     data: "base64_encoded_image_data" # if type is "base64"
          #   }
          # }
          #
          # NOTE: This method is currently not getting properly formatted images from the Content class
          # in vision-related tests. Debug logs show this method isn't being called with valid image data.

          # Basic validation - return nil for invalid image data
          return nil unless image.is_a?(Hash)

          # Log detailed information about image formatting attempts in debug mode
          RubyLLM.logger.debug "Formatting image: #{image.inspect}" if ENV["DEBUG"]

          result = nil

          if image[:url] && !image[:url].empty?
            result = {
              type: "image",
              source: {
                type: "url",
                url: image[:url],
              },
            }
          elsif image[:data] && !image[:data].empty?
            result = {
              type: "image",
              source: {
                type: "base64",
                media_type: image[:media_type] || "image/jpeg",
                data: image[:data],
              },
            }
          elsif image[:source] && image[:source].is_a?(Hash)
            # The image may already be in the correct format for Mistral
            # Just do some basic validation
            if (image[:source][:type] == "url" && image[:source][:url]) ||
               (image[:source][:type] == "base64" && image[:source][:data])
              result = image
            end
          end

          if result.nil?
            RubyLLM.logger.warn "WARNING: Unable to format image: #{image.inspect}"
          end

          result
        end

        def render_tool_call(tool_call)
          {
            id: tool_call.id,
            type: "function",
            function: {
              name: tool_call.name,
              arguments: tool_call.arguments,
            },
          }
        end

        def render_tool(tool)
          {
            type: "function",
            function: {
              name: tool.name,
              description: tool.description,
              parameters: {
                type: "object",
                properties: tool.parameters.transform_values { |param| param_schema(param) },
                required: tool.parameters.select { |_, p| p.required }.keys,
              },
            },
          }
        end

        def param_schema(param)
          {
            type: param.type,
            description: param.description,
          }.compact
        end

        def parse_completion_response(response)
          choice = response.body.dig("choices", 0)
          return unless choice

          Message.new(
            role: choice.dig("message", "role")&.to_sym,
            content: choice.dig("message", "content"),
            tool_calls: parse_tool_calls(choice.dig("message", "tool_calls")),
            input_tokens: response.body.dig("usage", "prompt_tokens"),
            output_tokens: response.body.dig("usage", "completion_tokens"),
            model_id: response.body["model"],
          )
        end

        def parse_tool_calls(tool_calls)
          return unless tool_calls

          tool_calls.to_h do |tc|
            [
              tc["id"],
              ToolCall.new(
                id: tc["id"],
                name: tc.dig("function", "name"),
                arguments: parse_tool_arguments(tc.dig("function", "arguments")),
              ),
            ]
          end
        end

        def parse_tool_arguments(args)
          return args unless args.is_a?(String)

          # Mistral returns arguments as a JSON string, so we need to parse it here
          # While this kind of handling could be moved to the main library,
          # keeping it in the provider maintains clean separation of concerns
          # and ensures that we don't break other providers that may handle arguments differently
          begin
            JSON.parse(args)
          rescue JSON::ParserError
            # If parsing fails, return the original string
            args
          end
        end

        # Helper method to check if a model supports vision capabilities
        def supports_vision?(model_id)
          Mistral.capabilities.supports_vision?(model_id)
        end

        # Debugging helper to assist with troubleshooting image handling issues
        # This is a comprehensive method that logs detailed information about the content
        # being processed to help identify issues with image handling.
        def debug_image_handling(messages, formatted_messages)
          return unless ENV["DEBUG"]

          RubyLLM.logger.debug "==== IMAGE HANDLING DIAGNOSTICS ===="

          messages.each_with_index do |msg, i|
            next unless msg.content.is_a?(Array)

            RubyLLM.logger.debug "Message #{i}: Original content array:"
            msg.content.each_with_index do |item, j|
              if item.nil?
                RubyLLM.logger.debug "  Item #{j}: NIL VALUE"
              elsif item.is_a?(Hash) && item[:type] == "image"
                has_url = item[:url] && !item[:url].empty?
                has_data = item[:data] && !item[:data].empty?
                has_source = item[:source] && item[:source].is_a?(Hash)

                details = []
                details << "url=#{item[:url].to_s[0..30]}..." if has_url
                details << "data_size=#{item[:data].to_s.size rescue "N/A"}" if has_data
                details << "source=#{item[:source].inspect}" if has_source

                RubyLLM.logger.debug "  Item #{j}: IMAGE - #{details.join(", ")}"
              else
                RubyLLM.logger.debug "  Item #{j}: #{item.class} - #{item.inspect[0..100]}..."
              end
            end

            if formatted_messages && formatted_messages[i] && formatted_messages[i][:content].is_a?(Array)
              RubyLLM.logger.debug "Message #{i}: Formatted content array:"
              formatted_messages[i][:content].each_with_index do |item, j|
                RubyLLM.logger.debug "  Item #{j}: #{item.inspect[0..100]}..."
              end
            end
          end

          RubyLLM.logger.debug "==== END DIAGNOSTICS ===="
        end
      end
    end
  end
end
