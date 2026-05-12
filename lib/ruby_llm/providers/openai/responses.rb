# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Responses API support for the OpenAI provider.
      module Responses
        RESPONSE_REASONING_TEXT_TYPES = %w[summary_text output_text].freeze

        def responses_url
          'responses'
        end

        module_function

        # rubocop:disable Metrics/ParameterLists
        def render_response_payload(messages, tools:, temperature:, model:, stream: false, schema: nil,
                                    thinking: nil, tool_prefs: nil, native_tools: nil)
          tool_prefs ||= {}
          payload = {
            model: model.id,
            input: format_response_input(messages),
            stream: stream,
            store: false
          }

          payload[:temperature] = temperature unless temperature.nil?
          apply_response_tools(payload, tools, native_tools, tool_prefs)
          apply_response_schema(payload, schema) if schema
          apply_response_thinking(payload, thinking)
          payload
        end
        # rubocop:enable Metrics/ParameterLists

        def format_response_input(messages)
          messages.flat_map do |message|
            if message.tool_call?
              format_response_tool_calls(message.tool_calls)
            elsif message.role == :tool
              format_response_tool_result(message)
            else
              format_response_message(message)
            end
          end
        end

        def parse_response_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          outputs = data['output'] || []
          return if outputs.empty?

          usage = data['usage'] || {}

          Message.new(
            role: :assistant,
            content: response_output_text(data),
            thinking: Thinking.build(text: response_reasoning_text(outputs)),
            tool_calls: parse_response_tool_calls(outputs),
            input_tokens: usage['input_tokens'],
            output_tokens: usage['output_tokens'],
            cached_tokens: usage.dig('input_tokens_details', 'cached_tokens'),
            cache_creation_tokens: usage.dig('input_tokens_details', 'cache_write_tokens') || 0,
            thinking_tokens: usage.dig('output_tokens_details', 'reasoning_tokens'),
            model_id: data['model'],
            raw: response
          )
        end

        def format_response_message(message)
          {
            type: 'message',
            role: format_role(message.role),
            content: format_response_content(message.content)
          }.compact
        end

        def format_response_tool_calls(tool_calls)
          tool_calls.map do |_, tool_call|
            {
              type: 'function_call',
              call_id: tool_call.id,
              name: tool_call.name,
              arguments: JSON.generate(tool_call.arguments || {})
            }
          end
        end

        def format_response_tool_result(message)
          {
            type: 'function_call_output',
            call_id: message.tool_call_id,
            output: response_tool_output(message.content)
          }
        end

        def apply_response_tools(payload, tools, native_tools, tool_prefs)
          response_tools = tools.map { |_, tool| response_tool_for(tool) }
          response_tools.concat(Utils.to_safe_array(native_tools))
          payload[:tools] = response_tools if response_tools.any?
          payload[:tool_choice] = build_response_tool_choice(tool_prefs[:choice]) unless tool_prefs[:choice].nil?
          payload[:parallel_tool_calls] = tool_prefs[:calls] == :many unless tool_prefs[:calls].nil?
        end

        def apply_response_schema(payload, schema)
          payload[:text] = {
            format: {
              type: 'json_schema',
              name: schema[:name],
              schema: schema[:schema],
              strict: schema[:strict]
            }
          }
        end

        def apply_response_thinking(payload, thinking)
          effort = resolve_effort(thinking)
          payload[:reasoning] = { effort: effort } if effort
        end

        def format_response_content(content)
          return content.value if content.is_a?(RubyLLM::Content::Raw)
          return content.to_json if content.is_a?(Hash) || content.is_a?(Array)
          return content unless content.is_a?(Content)

          parts = []
          parts << format_response_text(content.text) if content.text

          content.attachments.each do |attachment|
            parts << format_response_attachment(attachment)
          end

          parts
        end

        def format_response_attachment(attachment)
          case attachment.type
          when :image
            {
              type: 'input_image',
              image_url: attachment.url? ? attachment.source.to_s : attachment.for_llm
            }
          when :pdf
            {
              type: 'input_file',
              filename: attachment.filename,
              file_data: attachment.for_llm
            }
          when :text
            format_response_text(attachment.for_llm)
          when :audio
            raise UnsupportedAttachmentError, 'OpenAI Responses API does not support audio inputs yet'
          else
            raise UnsupportedAttachmentError, attachment.type
          end
        end

        def format_response_text(text)
          {
            type: 'input_text',
            text: text
          }
        end

        def response_tool_output(content)
          return JSON.generate(content.value) if content.is_a?(RubyLLM::Content::Raw)
          return content.text.to_s if content.is_a?(RubyLLM::Content) && content.text
          return JSON.generate(content.to_h) if content.is_a?(RubyLLM::Content)
          return JSON.generate(content) if content.is_a?(Hash) || content.is_a?(Array)

          content.to_s
        end

        def response_output_text(data)
          output_text = data['output_text']
          return output_text if output_text.is_a?(String) && !output_text.empty?

          text = response_output_text_parts(data['output']).join
          text.empty? ? nil : text
        end

        def response_output_text_parts(outputs)
          Utils.to_safe_array(outputs).select { |output| output['type'] == 'message' }.flat_map do |output|
            Utils.to_safe_array(output['content']).filter_map do |content|
              content['text'] if content['type'] == 'output_text' && content['text'].is_a?(String)
            end
          end
        end

        def response_reasoning_text(outputs)
          text = outputs.select { |output| output['type'] == 'reasoning' }.flat_map do |output|
            Utils.to_safe_array(output['summary'] || output['content']).filter_map do |content|
              if RESPONSE_REASONING_TEXT_TYPES.include?(content['type']) && content['text'].is_a?(String)
                content['text']
              end
            end
          end.join

          text.empty? ? nil : text
        end
      end
    end
  end
end
