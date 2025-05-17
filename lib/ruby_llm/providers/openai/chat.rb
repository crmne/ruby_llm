# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Chat methods of the OpenAI API integration
      module Chat
        def completion_url
          'chat/completions'
        end

        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false)
          {
            model: model,
            messages: format_messages(messages),
            temperature: temperature,
            stream: stream
          }.tap do |payload|
            if tools.any?
              payload[:tools] = tools.map { |_, tool| tool_for(tool) }
              payload[:tool_choice] = 'auto'
            end

            add_response_schema_to_payload(payload) if response_schema.present?

            payload[:stream_options] = { include_usage: true } if stream
          end
        end

        def parse_completion_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          message_data = data.dig('choices', 0, 'message')
          return unless message_data

          Message.new(
            role: :assistant,
            content_schema: response_schema,
            content: message_data['content'],
            tool_calls: parse_tool_calls(message_data['tool_calls']),
            input_tokens: data['usage']['prompt_tokens'],
            output_tokens: data['usage']['completion_tokens'],
            model_id: data['model']
          )
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: Media.format_content(msg.content),
              tool_calls: format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact
          end
        end

        def format_role(role)
          case role
          when :system
            'developer'
          else
            role.to_s
          end
        end

        private

        ##
        # @param [Hash] payload
        def add_response_schema_to_payload(payload)
          payload[:response_format] = gen_response_format_request

          return unless payload[:response_format][:type] == :json_object

          # NOTE: this is required by the Open AI API when requesting arbitrary JSON.
          payload[:messages].unshift({ role: :developer, content: <<~GUIDANCE
            You must format your output as a valid JSON object.
            Format your entire response as valid JSON.
            Do not include explanations, markdown formatting, or any text outside the JSON.
          GUIDANCE
          })
        end

        ##
        # @return [Hash]
        def gen_response_format_request
          if response_schema[:type].to_s == :object.to_s && response_schema[:properties].to_h.keys.none?
            { type: :json_object } # Assume we just want json_mode
          else
            gen_json_schema_format_request
          end
        end

        def gen_json_schema_format_request # rubocop:disable Metrics/MethodLength -- because it's mostly the standard hash
          result_schema = response_schema.dup # so we don't modify the original in the thread
          result_schema.add_to_each_object_type!(:additionalProperties, false)
          result_schema.add_to_each_object_type!(:required, ->(schema) { schema[:properties].to_h.keys })

          {
            type: :json_schema,
            json_schema: {
              name: :response,
              schema: {
                type: :object,
                properties: { result: result_schema.to_h },
                additionalProperties: false,
                required: [:result]
              },
              strict: true
            }
          }
        end
      end
    end
  end
end
