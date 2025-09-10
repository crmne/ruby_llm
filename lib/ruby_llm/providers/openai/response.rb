# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Response methods of the OpenAI API integration
      module Response
        def responses_url
          'responses'
        end

        module_function

        def render_response_payload(messages, tools:, temperature:, model:, stream: false, schema: nil) # rubocop:disable Metrics/ParameterLists
          payload = {
            model: model.id,
            input: format_input(messages),
            stream: stream
          }

          # Only include temperature if it's not nil (some models don't accept it)
          payload[:temperature] = temperature unless temperature.nil?

          payload[:tools] = tools.map { |_, tool| response_tool_for(tool) } if tools.any?

          if schema
            # Use strict mode from schema if specified, default to true
            strict = schema[:strict] != false

            payload[:text] = {
              format: {
                type: 'json_schema',
                name: 'response',
                schema: schema,
                strict: strict
              }
            }
          end

          payload
        end

        def format_input(messages)
          all_tool_calls = messages.flat_map do |m|
            m.tool_calls&.values || []
          end
          messages.flat_map { |msg| format_message_input(msg, all_tool_calls) }.flatten
        end

        def format_message_input(msg, all_tool_calls)
          if msg.tool_call?
            format_tool_call_message(msg)
          elsif msg.role == :tool
            format_tool_response_message(msg, all_tool_calls)
          elsif assistant_message_with_image_attachment?(msg)
            format_image_generation_message(msg)
          else
            format_regular_message(msg)
          end
        end

        def format_tool_call_message(msg)
          msg.tool_calls.map do |_, tc|
            {
              type: 'function_call',
              call_id: tc.id,
              name: tc.name,
              arguments: JSON.generate(tc.arguments),
              status: 'completed'
            }
          end
        end

        def format_tool_response_message(msg, all_tool_calls)
          {
            type: 'function_call_output',
            call_id: all_tool_calls.detect { |tc| tc.id == msg.tool_call_id }&.id,
            output: msg.content,
            status: 'completed'
          }
        end

        def format_image_generation_message(msg)
          items = []
          image_attachment = msg.content.attachments.last
          if image_attachment.reasoning_id
            items << {
              type: 'reasoning',
              id: image_attachment.reasoning_id,
              summary: []
            }
          end
          items << {
            type: 'image_generation_call',
            id: image_attachment.id
          }
          items
        end

        def format_regular_message(msg)
          {
            type: 'message',
            role: format_role(msg.role),
            content: ResponseMedia.format_content(msg.content),
            status: 'completed'
          }.compact
        end

        def format_role(role)
          case role
          when :system
            'developer'
          else
            role.to_s
          end
        end

        def parse_respond_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          outputs = data['output']
          return unless outputs.any?

          Message.new(
            role: :assistant,
            content: all_output_content(outputs),
            tool_calls: parse_response_tool_calls(outputs),
            input_tokens: data['usage']['input_tokens'],
            output_tokens: data['usage']['output_tokens'],
            cached_tokens: data.dig('usage', 'input_tokens_details', 'cached_tokens'),
            model_id: data['model'],
            reasoning_id: extract_reasoning_id(outputs),
            raw: response
          )
        end

        def all_output_content(outputs)
          @current_outputs = outputs
          text_content = extract_text_content(outputs)
          image_outputs = outputs.select { |o| o['type'] == 'image_generation_call' }

          return text_content unless image_outputs.any?

          build_content_with_images(image_outputs, text_content)
        end

        private

        def extract_text_content(outputs)
          outputs.select { |o| o['type'] == 'message' }.flat_map do |o|
            o['content'].filter_map do |c|
              c['type'] == 'output_text' && c['text']
            end
          end.join("\n")
        end

        def build_content_with_images(image_outputs, text_content)
          reasoning_id = extract_reasoning_id(@current_outputs)
          content = RubyLLM::Content.new(text_content)
          image_outputs.each do |output|
            attach_image_to_content(content, output, reasoning_id)
          end
          content
        end

        def attach_image_to_content(content, output, reasoning_id)
          image_data = output['result']
          output_format = output['output_format'] || 'png'
          mime_type = "image/#{output_format}"

          content.attach(
            RubyLLM::ImageAttachment.new(
              data: image_data,
              mime_type: mime_type,
              model_id: nil,
              id: output['id'],
              reasoning_id: reasoning_id,
              revised_prompt: output['revised_prompt']
            )
          )
        end

        def all_output_text(outputs)
          outputs.select { |o| o['type'] == 'message' }.flat_map do |o|
            o['content'].filter_map do |c|
              c['type'] == 'output_text' && c['text']
            end
          end.join("\n")
        end

        def assistant_message_with_image_attachment?(msg)
          msg.role == :assistant &&
            msg.content.is_a?(RubyLLM::Content) &&
            msg.content.attachments.any? &&
            msg.content.attachments.last.is_a?(RubyLLM::ImageAttachment)
        end

        def extract_reasoning_id(outputs)
          reasoning_item = outputs.find { |o| o['type'] == 'reasoning' }
          reasoning_item&.dig('id')
        end
      end
    end
  end
end
