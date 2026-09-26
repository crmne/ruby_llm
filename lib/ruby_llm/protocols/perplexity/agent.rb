# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Perplexity
      # Perplexity's Agent API, a dialect of the Responses API. A request names
      # either a preset, which bundles a model, search settings, and
      # instructions, or a model in provider/model form. The retired Sonar
      # model ids run the presets Perplexity recommends in their place.
      class Agent < Responses
        PRESETS = %w[fast low medium high xhigh wide-research].freeze
        SONAR_PRESETS = {
          'sonar' => 'fast',
          'sonar-pro' => 'low',
          'sonar-reasoning-pro' => 'medium',
          'sonar-deep-research' => 'high'
        }.freeze

        def completion_url
          @provider.agent_url
        end

        def render_payload(messages, model:, max_output_tokens: nil, **)
          max_output_tokens ||= default_max_output_tokens(model)
          payload = super
          preset = preset_for(model.id)
          return payload unless preset

          payload.delete(:model)
          payload.merge(preset: preset)
        end

        def format_document(document)
          raise UnsupportedAttachmentError, document.mime_type
        end

        private

        # Perplexity rejects Anthropic models without an output cap, so they get
        # the one the Anthropic protocol sends.
        def default_max_output_tokens(model)
          model.max_output_tokens || 4096 if model.id.start_with?('anthropic/')
        end

        def preset_for(model_id)
          return model_id if PRESETS.include?(model_id)

          preset = SONAR_PRESETS[model_id]
          if preset
            RubyLLM.deprecator.warn(
              "Perplexity retires Sonar on September 27, 2026. #{model_id} now runs the #{preset} " \
              "Agent API preset; use model: \"#{preset}\" instead."
            )
          end
          preset
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
            data['output_index'] => ToolCall.new(id: item['call_id'], name: item['name'],
                                                 arguments: +item['arguments'].to_s)
          }
        end

        # Perplexity rejects its own search_results and fetch_url_results
        # items as input, so a replayed turn keeps only messages, reasoning,
        # and function calls.
        def format_assistant_items(msg)
          super.select do |item|
            type = item[:type] || item['type']
            type.nil? || Responses::Chat::CLIENT_OUTPUT_ITEM_TYPES.include?(type)
          end
        end

        def supports_provider_file_references?
          false
        end
      end
    end
  end
end
