# frozen_string_literal: true

module RubyLLM
  module Protocols
    module GPUStack
      # vLLM Responses with MCP servers configured on the deployment.
      class Responses < Protocols::Responses
        MCP_LABELS = %w[web_search_preview code_interpreter container].freeze
        MCP_ALIASES = {
          web_search: ['web_search_preview', ['search']],
          web_fetch: ['web_search_preview', ['open']],
          code_execution: ['code_interpreter', nil]
        }.freeze
        SERVER_TOOL_ALIASES = MCP_ALIASES.transform_values do |label, tools|
          ->(options) { render_mcp_alias(options, label:, tools:) }
        end.merge(mcp: Protocols::Responses::SERVER_TOOL_ALIASES.fetch(:mcp)).freeze

        def self.render_mcp_alias(options, label:, tools:) # :nodoc:
          options = Support::Utils.deep_symbolize_keys(options)
          unless (options.keys - [:require_approval]).empty?
            raise ArgumentError, 'GPUStack server tool aliases accept only require_approval; use mcp for custom filters'
          end

          tool = { type: 'mcp', server_label: label, **options }
          tool[:allowed_tools] = tools.dup if tools
          { tool: }
        end

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def merge_server_tool_entries(payload, entries)
          tools = entries.map { |entry| Support::Utils.deep_symbolize_keys(entry) }
          tools.each do |tool|
            next unless tool[:type] == 'mcp'

            validate_mcp_tool(tool)
          end
          super(payload, merge_mcp_filters(tools))
        end

        def format_assistant_items(message)
          super.flat_map do |item|
            data = Support::Utils.deep_symbolize_keys(item)
            next item unless data[:type] && !Protocols::Responses::Chat::CLIENT_OUTPUT_ITEM_TYPES.include?(data[:type])

            format_server_tool_history(data)
          end
        end

        def parse_reasoning_summary(output)
          summary = super
          return summary unless summary.to_s.empty?

          text = output.select { |item| item['type'] == 'reasoning' }.flat_map { |item| item['content'] || [] }
                       .filter_map { |part| part['text'] }.join
          text unless text.empty?
        end

        private

        def merge_mcp_filters(tools)
          tools.each_with_object([]) do |tool, merged|
            existing = merged.find { |entry| entry[:type] == 'mcp' && entry[:server_label] == tool[:server_label] }
            if tool[:type] != 'mcp' || existing.nil?
              merged << tool
            elsif existing != tool
              merge_mcp_filter(existing, tool)
            end
          end
        end

        def merge_mcp_filter(existing, tool)
          filters = [existing[:allowed_tools], tool[:allowed_tools]]
          compatible = existing.except(:allowed_tools) == tool.except(:allowed_tools)
          unless compatible && filters.all? { |filter| filter.is_a?(Array) && !filter.include?('*') }
            raise ArgumentError, 'Combine GPUStack MCP settings for each server in one entry with explicit tool names'
          end

          existing[:allowed_tools] |= tool[:allowed_tools]
        end

        def format_server_tool_history(item)
          if item[:type] == 'mcp_call' && item[:name] && item[:id] && !item[:output].nil?
            output = item[:output].is_a?(String) ? item[:output] : JSON.generate(item[:output])
            [{ type: 'function_call', call_id: item[:id], name: item[:name], arguments: item[:arguments] },
             { type: 'function_call_output', call_id: item[:id], output: output }]
          else
            [{ role: 'assistant', content: [{ type: 'output_text', text: JSON.generate(item) }] }]
          end
        end

        def validate_mcp_tool(tool)
          unless tool[:require_approval].to_s == 'never'
            raise ArgumentError, "GPUStack MCP requires explicit require_approval: 'never'; vLLM has no approval events"
          end
          if tool[:server_url] || tool[:connector_id] || tool[:authorization]
            raise ArgumentError, 'GPUStack MCP uses servers configured on vLLM, not per-request URLs or connectors'
          end
          unless MCP_LABELS.include?(tool[:server_label])
            raise ArgumentError, "GPUStack MCP name must match a configured vLLM label: #{MCP_LABELS.join(', ')}"
          end
          return unless tool[:allowed_tools].is_a?(Hash) && tool[:allowed_tools][:read_only]

          raise ArgumentError, 'vLLM filters MCP tools by name, not by read_only; use allowed_tools: [name]'
        end
      end
    end
  end
end
