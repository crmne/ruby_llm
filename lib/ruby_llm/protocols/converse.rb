# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The AWS Bedrock Converse API. Requests are SigV4-signed by the provider.
    class Converse < Protocol
      include Converse::Chat
      include Converse::Media
      include Converse::Streaming

      # Nova 2 models execute built-in tools server-side when the request
      # names them as system tools.
      SERVER_TOOL_ALIASES = {
        web_search: lambda { |options|
          { tool: { systemTool: { name: 'nova_grounding' }.merge(Utils.deep_symbolize_keys(options)) } }
        }
      }.freeze

      def server_tool_aliases
        SERVER_TOOL_ALIASES
      end

      private

      # Converse carries tools under toolConfig.tools rather than a
      # top-level tools array.
      def merge_server_tool_entries(payload, entries)
        tool_config = payload[:toolConfig] ||= {}
        tool_config[:tools] = Array(tool_config[:tools]) + entries
        payload
      end

      def sync_response(payload, additional_headers = {})
        response = signed_post(completion_url, payload, additional_headers)
        parse_completion_response(response)
      end

      def post_count_tokens(payload)
        signed_post(count_tokens_url, payload)
      end

      def signed_post(url, payload, additional_headers = {})
        body = JSON.generate(payload)

        @connection.post(url, payload, usage: @usage_tracker) do |req|
          req.headers.merge!(@provider.sign_headers('POST', url, body))
          req.headers.merge!(additional_headers) unless additional_headers.empty?
        end
      end
    end
  end
end
