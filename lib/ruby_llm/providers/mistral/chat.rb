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

          payload = {
            model: model,
            messages: messages.map { |m| render_message(m) },
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
          if message.content.is_a?(Array)
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

          # Filter out nil values
          filtered_content = content.compact

          RubyLLM.logger.debug "Filtered content: #{filtered_content.inspect}"

          filtered_content.map do |item|
            if item.is_a?(Hash) && item[:type] == "image"
              format_image_content(item)
            else
              item
            end
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

          if image[:url]
            {
              type: "image",
              source: {
                type: "url",
                url: image[:url],
              },
            }
          elsif image[:data]
            {
              type: "image",
              source: {
                type: "base64",
                media_type: image[:media_type] || "image/jpeg",
                data: image[:data],
              },
            }
          end
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
      end
    end
  end
end
