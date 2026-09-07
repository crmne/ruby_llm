# frozen_string_literal: true

module RubyLLM
  module Protocols
    module OpenRouter
      # OpenRouter's opt-in Responses endpoint and hosted tools.
      class Responses < Protocols::Responses
        SERVER_TOOL_ALIASES = %i[web_search web_fetch datetime image_generation apply_patch shell].to_h do |name|
          [name, { tool: { type: "openrouter:#{name}" } }]
        end.merge(
          url_context: { tool: { type: 'openrouter:web_fetch' } },
          code_execution: { tool: { type: 'openrouter:shell' } },
          mcp: Protocols::Responses::SERVER_TOOL_ALIASES.fetch(:mcp)
        ).freeze

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def merge_server_tool_entries(payload, entries)
          entries.each do |entry|
            tool = Support::Utils.deep_symbolize_keys(entry)
            next unless tool[:type] == 'mcp'
            next if tool[:require_approval].to_s == 'never'

            raise ArgumentError,
                  "OpenRouter MCP requires explicit require_approval: 'never'; approval events are not returned"
          end
          super
        end

        def parse_usage(usage)
          super.merge(reported_cost: reported_cost(usage), server_tool_use: server_tool_use(usage))
        end

        def reported_cost(usage)
          cost = usage['cost']
          return nil unless cost

          cost += usage.dig('cost_details', 'upstream_inference_cost').to_f if usage['is_byok']
          cost
        end

        def build_chunk(data)
          return super unless data['type'] == 'response.mcp_call_arguments.done'

          chunk server_tool_calls: [ServerToolCall.new(type: 'mcp_call', id: data['item_id'],
                                                       input: data['arguments'], raw: data)]
        end
      end
    end
  end
end
