# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenRouter API integration.
    class OpenRouter < Provider
      BAD_GATEWAY = 502

      # OpenRouter's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include OpenRouter::Chat
        include OpenRouter::Embeddings
        include OpenRouter::Images
        include OpenRouter::Models
        include OpenRouter::Speech
        include OpenRouter::Streaming
        include Protocols::ChatCompletions::Rerank
        include OpenRouter::Videos
        include Protocols::OpenRouter::Transcription

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

      # OpenRouter's dialect of the System One API for decision models such as Jev and Clef.
      class SystemOne < Protocols::SystemOne
        include OpenRouter::Judgments
      end

      protocol :chat_completions, ChatCompletions, batches: Protocols::OpenRouter::Batches
      protocol :responses, Protocols::OpenRouter::Responses
      protocol :files, Protocols::OpenRouter::Files
      protocol :system_one, SystemOne

      def resolve_protocol(name, model, operation: nil, **options)
        name ||= (operation == :judge ? :system_one : :chat_completions) if operation
        super
      end

      def api_base
        @config.openrouter_api_base || 'https://openrouter.ai/api/v1'
      end

      def batch_api_base
        "#{api_base.sub(%r{/v1/?\z}, '')}/beta/batches"
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.openrouter_api_key}",
          'HTTP-Referer' => @config.openrouter_app_url || 'https://rubyllm.com',
          'X-OpenRouter-Title' => @config.openrouter_app_name || 'RubyLLM'
        }
      end

      def account_identity
        account_digest(api_base, @config.openrouter_api_key)
      end

      def parse_error(response)
        body = parse_error_body(response)
        return unless body

        case body
        when Hash
          parse_error_part_message body
        when Array
          messages = body.filter_map do |part|
            parse_error_part_message part
          end.reject(&:empty?)
          messages.join('. ') unless messages.empty?
        else
          body
        end
      end

      # OpenRouter answers 200 when an upstream provider fails after routing,
      # with an error object or an empty body. A stream has no body here.
      def error_status(response)
        return if response.request.stream_response?

        body = response.body.to_s
        return BAD_GATEWAY if body.strip.empty?
        return unless body.include?('"error"')

        error = parse_error_body(response).then { |parsed| parsed['error'] if parsed.is_a?(Hash) }
        return unless error.is_a?(Hash)

        code = error['code']
        code.is_a?(Integer) && code >= 400 ? code : BAD_GATEWAY
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
