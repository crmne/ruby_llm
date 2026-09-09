# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The OpenAI Responses API. Overrides the chat surface of Chat Completions;
    # embeddings, images, moderation, and transcription are inherited. Runs
    # stateless (store: false) and replays encrypted reasoning so multi-turn
    # tool calls work without server-side state.
    class Responses < ChatCompletions
      include Responses::Approvals
      include Responses::Chat
      include Responses::Media
      include Responses::Streaming
      include Responses::Tools

      SERVER_TOOL_ALIASES = {
        web_search: { tool: { type: 'web_search' } },
        file_search: { tool: { type: 'file_search' } },
        code_execution: { tool: { type: 'code_interpreter', container: { type: 'auto' } } },
        code_interpreter: { tool: { type: 'code_interpreter', container: { type: 'auto' } } },
        image_generation: { tool: { type: 'image_generation' } },
        mcp: lambda do |options|
          options = Support::Utils.deep_symbolize_keys(options)
          options[:server_url] = options.delete(:url) if options.key?(:url)
          options[:server_label] = options.delete(:name) if options.key?(:name)
          { tool: { type: 'mcp' }.merge(options) }
        end
      }.freeze

      def server_tool_aliases
        SERVER_TOOL_ALIASES
      end
    end
  end
end
