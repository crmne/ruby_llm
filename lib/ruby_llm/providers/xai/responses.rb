# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # xAI's dialect of the OpenAI Responses API, the primary protocol for
      # Grok models. Every Grok model reasons and returns encrypted reasoning,
      # temperature stays supported, and usage counts agentic tool activity.
      class Responses < Protocols::Responses
        include XAI::Images
        include XAI::Models
        include XAI::Speech
        include XAI::Transcription

        SERVER_TOOL_ALIASES = {
          web_search: { tool: { type: 'web_search' } },
          x_search: { tool: { type: 'x_search' } },
          code_execution: { tool: { type: 'code_execution' } },
          code_interpreter: { tool: { type: 'code_interpreter' } },
          file_search: { tool: { type: 'file_search' } },
          collections_search: { tool: { type: 'file_search' } },
          image_generation: { tool: { type: 'image_generation' } },
          mcp: { tool: { type: 'mcp' } }
        }.freeze

        SERVER_TOOL_USAGE_COUNTERS = %w[num_sources_used num_server_side_tools_used].freeze

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def reasoning_model?(_model_id)
          true
        end

        def maybe_normalize_temperature(temperature, _model)
          temperature
        end

        def parse_usage(usage)
          super.merge(server_tool_use: server_side_tool_usage(usage))
        end

        private

        def server_side_tool_usage(usage)
          counters = usage.slice(*SERVER_TOOL_USAGE_COUNTERS).reject { |_, count| count.to_i.zero? }
          counters.empty? ? nil : counters
        end
      end
    end
  end
end
