# frozen_string_literal: true

require 'time'

module RubyLLM
  module Protocols
    class Anthropic
      # Models methods of the Anthropic API integration
      module Models
        ITERATION_TOKEN_KEYS = %w[
          input_tokens output_tokens cache_read_input_tokens cache_creation_input_tokens
        ].freeze

        REPORTED_CAPABILITIES = {
          'batch' => 'batch',
          'citations' => 'citations',
          'image_input' => 'vision',
          'structured_outputs' => 'structured_output',
          'thinking' => 'reasoning'
        }.freeze

        def list_models
          models = []
          after_id = nil

          loop do
            response = @connection.get(models_url) do |req|
              req.params = { limit: 1000 }
              req.params[:after_id] = after_id if after_id
            end

            models.concat(parse_list_models_response(response, @provider.slug))
            break unless response.body['has_more']

            after_id = response.body['last_id']
          end

          models
        end

        private

        def models_url
          'v1/models'
        end

        def parse_list_models_response(response, slug)
          Array(response.body['data']).map do |model_data|
            model_id = model_data['id']

            Model.new(
              id: model_id,
              name: model_data['display_name'] || model_id,
              provider: slug,
              created_at: Time.parse(model_data['created_at']),
              context_window: model_data['max_input_tokens'],
              max_output_tokens: model_data['max_tokens'],
              capabilities: model_capabilities(model_data),
              metadata: {}
            )
          end
        end

        def model_capabilities(model_data)
          reported = model_data['capabilities']
          return [] unless reported.is_a?(Hash)

          reported.filter_map do |name, detail|
            REPORTED_CAPABILITIES[name] if detail.is_a?(Hash) && detail['supported']
          end
        end

        def extract_model_id(data)
          data.dig('message', 'model')
        end

        def extract_input_tokens(data)
          message_usage(data)['input_tokens']
        end

        def extract_output_tokens(data)
          message_usage(data)['output_tokens'] || delta_usage(data)['output_tokens']
        end

        def extract_thinking_tokens(data)
          message_usage(data).dig('output_tokens_details', 'thinking_tokens') ||
            delta_usage(data).dig('output_tokens_details', 'thinking_tokens')
        end

        def extract_cache_read_tokens(data)
          message_usage(data)['cache_read_input_tokens'] || delta_usage(data)['cache_read_input_tokens']
        end

        def extract_cache_write_tokens(data)
          direct = message_usage(data)['cache_creation_input_tokens'] ||
                   delta_usage(data)['cache_creation_input_tokens']
          return direct if direct

          breakdown = message_usage(data)['cache_creation'] || delta_usage(data)['cache_creation']
          return unless breakdown.is_a?(Hash)

          breakdown.values.compact.sum
        end

        def message_usage(data)
          aggregate_usage(data.dig('message', 'usage'))
        end

        def delta_usage(data)
          aggregate_usage(data['usage'])
        end

        # A compacted turn runs the model more than once, and the top-level
        # counts cover only the final iteration. Everything billed is in
        # usage.iterations, so their sum is what the request cost.
        def aggregate_usage(usage)
          return {} unless usage.is_a?(Hash)

          iterations = usage['iterations']
          return usage unless iterations.is_a?(Array) && !iterations.empty?

          usage.merge(ITERATION_TOKEN_KEYS.to_h do |key|
            [key, iterations.sum { |iteration| iteration[key].to_i }]
          end)
        end
      end
    end
  end
end
