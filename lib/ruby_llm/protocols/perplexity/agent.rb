# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Perplexity
      # Perplexity's Agent API, a dialect of the Responses API. A request names
      # either a preset, which bundles a model, search settings, and
      # instructions, or a model in provider/model form.
      class Agent < Responses
        PRESETS = %w[fast low medium high xhigh wide-research].freeze
        SERVER_TOOL_ALIASES = Responses::SERVER_TOOL_ALIASES.merge(
          web_fetch: { tool: { type: 'fetch_url' } },
          code_execution: { tool: { type: 'sandbox' } },
          code_interpreter: { tool: { type: 'sandbox' } }
        ).freeze
        SERVER_TOOL_USAGE_NAMES = {
          'search_web' => 'web_search',
          'fetch_url' => 'web_fetch',
          'sandbox' => 'code_execution'
        }.freeze

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def completion_url
          @provider.agent_url
        end

        def render_payload(messages, model:, max_output_tokens: nil, **)
          max_output_tokens ||= default_max_output_tokens(model)
          payload = super
          return payload unless PRESETS.include?(model.id)

          payload.delete(:model)
          payload.merge(preset: model.id)
        end

        private

        def default_max_output_tokens(model)
          model.max_output_tokens || Anthropic::DEFAULT_MAX_OUTPUT_TOKENS if model.id.start_with?('anthropic/')
        end

        def parse_citations(data, output, content)
          citations = super
          return citations if citations.any?

          results = output.select { |item| item['type'] == 'search_results' }.flat_map { |item| Array(item['results']) }
          parse_search_results(results)
        end

        def parse_usage(usage)
          details = usage['input_tokens_details'] || {}
          details = { 'cache_write_tokens' => details['cache_creation_input_tokens'] }.merge(details)

          super(usage.merge('input_tokens_details' => details)).merge(reported_cost: usage.dig('cost', 'total_cost'))
        end

        def parse_server_tool_use(response)
          response.dig('usage', 'tool_calls_details').to_h.to_h do |tool, details|
            ["#{SERVER_TOOL_USAGE_NAMES.fetch(tool, tool)}_requests", details['invocation']]
          end
        end

        # Perplexity sends each function call whole, without argument deltas,
        # and announces its own web searches as function calls whose items
        # finish as search_results. Only a finished function_call item is a
        # call for the application to run.
        def build_item_added_chunk(data)
          data.dig('item', 'type') == 'function_call' ? chunk : super
        end

        def build_item_done_chunk(data)
          item = data['item']
          return super unless item['type'] == 'function_call'

          chunk tool_calls: {
            data['output_index'] => ToolCall.new(provider_call_id: item['call_id'], name: item['name'],
                                                 arguments: +item['arguments'].to_s)
          }
        end

        # Perplexity rejects its own search_results and fetch_url_results
        # items as input, so a replayed turn keeps only messages, reasoning,
        # and function calls.
        def render_assistant_items(msg)
          super.select do |item|
            type = item[:type] || item['type']
            type.nil? || Responses::Chat::CLIENT_OUTPUT_ITEM_TYPES.include?(type)
          end
        end

        def provider_file_references?
          false
        end
      end
    end
  end
end
