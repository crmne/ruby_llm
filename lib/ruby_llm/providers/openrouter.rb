# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenRouter API integration.
    class OpenRouter < Provider
      # OpenRouter's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include OpenRouter::Chat
        include OpenRouter::Images
        include OpenRouter::Models
        include OpenRouter::Speech
        include OpenRouter::Streaming

        # OpenRouter runs its server tools transparently: results surface as
        # citations and usage counters rather than discrete content blocks.
        SERVER_TOOL_ALIASES = %i[
          web_search web_fetch datetime image_generation apply_patch shell
        ].to_h { |name| [name, { tool: { type: "openrouter:#{name}" } }] }.merge(
          url_context: { tool: { type: 'openrouter:web_fetch' } },
          code_execution: { tool: { type: 'openrouter:shell' } }
        ).freeze

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end
      end

      protocol :chat_completions, ChatCompletions
      files OpenRouter::Files

      def api_base
        @config.openrouter_api_base || 'https://openrouter.ai/api/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.openrouter_api_key}",
          'HTTP-Referer' => @config.openrouter_app_url || 'https://rubyllm.com',
          'X-OpenRouter-Title' => @config.openrouter_app_name || 'RubyLLM'
        }
      end

      def parse_error(response)
        body = parse_error_body(response)
        return unless body

        case body
        when Hash
          parse_error_part_message body
        when Array
          body.map do |part|
            parse_error_part_message part
          end.join('. ')
        else
          body
        end
      end

      class << self
        def configuration_options
          %i[openrouter_api_key openrouter_api_base openrouter_app_url openrouter_app_name]
        end

        def configuration_requirements
          %i[openrouter_api_key]
        end
      end

      private

      def parse_error_part_message(part)
        return error_message(part) unless part.is_a?(Hash)

        error = part['error']
        message = error_message(error)
        metadata = error['metadata'] if error.is_a?(Hash)
        return message unless metadata.is_a?(Hash)

        raw = try_parse_json(metadata['raw'])
        return message unless raw.is_a?(Hash)

        raw_message = error_message(raw['error'])
        return [message, raw_message].compact.join(' - ') if raw_message

        message
      end

      def error_message(value)
        case value
        when Hash
          value['message']
        when Array
          messages = value.filter_map { |part| error_message(part) }
          messages.join('. ') unless messages.empty?
        when nil
          nil
        else
          value.to_s
        end
      end
    end
  end
end
