# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Chat methods for the AWS Bedrock API implementation
      module Chat
        module_function

        def sync_response(connection, payload)
          signature = sign_request("#{connection.connection.url_prefix}#{completion_url}", config: connection.config,
                                                                                           payload:)
          response = connection.post completion_url, payload do |req|
            req.headers.merge! build_headers(signature.headers, streaming: block_given?)
          end
          Anthropic::Chat.parse_completion_response response
        end

        def format_message(msg, cache: false)
          if msg.tool_call?
            Anthropic::Tools.format_tool_call(msg)
          elsif msg.tool_result?
            Anthropic::Tools.format_tool_result(msg)
          else
            format_basic_message(msg, cache:)
          end
        end

        def format_basic_message(msg, cache: false)
          {
            role: Anthropic::Chat.convert_role(msg.role),
            content: Media.format_content(msg.content, cache:)
          }
        end

        private

        def completion_url
          "model/#{@model_id}/invoke"
        end

        def render_payload(params)
          # Hold model_id in instance variable for use in completion_url and stream_url
          @model_id = params.model

          system_messages, chat_messages = Anthropic::Chat.separate_messages(params.messages)
          system_content = Anthropic::Chat.build_system_content(system_messages, cache: params.cache_prompts[:system])

          build_base_payload(chat_messages, params.temperature, params.model,
                             cache: params.cache_prompts[:user]).tap do |payload|
            Anthropic::Chat.add_optional_fields(
              payload,
              system_content: system_content,
              tools: params.tools,
              cache_tools: params.cache_prompts[:tools]
            )
          end
        end

        def build_base_payload(chat_messages, temperature, model, cache: false)
          messages = chat_messages.map.with_index do |msg, idx|
            cache = false unless idx == chat_messages.size - 1
            format_message(msg, cache:)
          end
          {
            anthropic_version: 'bedrock-2023-05-31',
            messages: messages,
            temperature: temperature,
            max_tokens: RubyLLM.models.find(model)&.max_tokens || 4096
          }
        end
      end
    end
  end
end
