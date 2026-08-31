# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenAI API integration.
    class OpenAI < Provider
      protocol :responses, Protocols::Responses, batches: Protocols::Responses::Batches
      protocol :chat_completions, Protocols::ChatCompletions, batches: Protocols::ChatCompletions::Batches
      protocol :embeddings, Protocols::ChatCompletions,
               batches: Protocols::ChatCompletions::EmbeddingBatches
      protocol :files, Protocols::OpenAI::Files

      RATE_LIMIT_RESET_HEADERS = %w[x-ratelimit-reset-requests x-ratelimit-reset-tokens].freeze
      RESET_DURATION_UNITS = { 'h' => 3600, 'm' => 60, 's' => 1, 'ms' => 0.001 }.freeze

      def api_base
        @config.openai_api_base || 'https://api.openai.com/v1'
      end

      # Audio, realtime, and search-preview models only exist on Chat Completions.
      def protocol_for(model, **)
        model.id.match?(/audio|realtime|search-preview/) ? protocols[:chat_completions] : super
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.openai_api_key}",
          'OpenAI-Organization' => @config.openai_organization_id,
          'OpenAI-Project' => @config.openai_project_id
        }.compact
      end

      # OpenAI reports when each rate limit resets in its own headers,
      # as durations like "6m0s", "7.66s" or "76ms".
      def retry_delay(response)
        headers = response.response_headers
        return unless headers

        RATE_LIMIT_RESET_HEADERS.filter_map { |header| parse_reset_duration(headers[header]) }.max
      end

      def find_batch(id)
        batch = super
        protocol = batch_protocol_for_endpoint(batch[:endpoint])

        protocol ? batch.merge(batch_protocol: protocol) : batch
      end

      def batch_results(id, batch_protocol: nil)
        super(id, batch_protocol: resolve_batch_protocol(batch_protocol) || batch_protocol_for_stored_batch(id))
      end

      def batch_cost_multiplier(**) = 0.5

      class << self
        def capabilities
          OpenAI::Capabilities
        end

        def models_dev_alias(...)
          OpenAI::Models.models_dev_alias(...)
        end

        def configuration_options
          %i[
            openai_api_key
            openai_api_base
            openai_organization_id
            openai_project_id
            openai_use_system_role
          ]
        end

        def configuration_requirements
          %i[openai_api_key]
        end
      end

      private

      def parse_reset_duration(value)
        duration = value.to_s
        parts = duration.scan(/(\d+(?:\.\d+)?)(ms|h|m|s)/)
        return if parts.empty?
        return unless parts.map { |amount, unit| "#{amount}#{unit}" }.join == duration

        parts.sum { |amount, unit| amount.to_f * RESET_DURATION_UNITS[unit] }
      end

      def batch_protocol
        batch_protocol_for_name(:responses)
      end

      def batch_protocol_for(requests)
        names = requests.map { |request| batch_protocol_name_for(request.fetch(:payload)) }.uniq
        return batch_protocol_for_name(names.first) if names.one?

        raise Error, 'openai batch requests must target one endpoint per submission'
      end

      def batch_protocol_name_for(payload)
        input = payload[:input] || payload['input']
        return :embeddings if embeddings_input?(input)
        return :responses if input
        return :chat_completions if payload.key?(:messages) || payload.key?('messages')

        raise Error, 'openai batch requests only support chat, responses, or embedding payloads'
      end

      # Responses payloads carry the conversation as an array of message hashes
      # under :input; embedding payloads put the text itself there.
      def embeddings_input?(input)
        input.is_a?(String) || (input.is_a?(Array) && !input.empty? && input.all?(String))
      end

      def batch_protocol_for_stored_batch(id)
        data = @connection.get("batches/#{id}").body
        batch_protocol_for_endpoint(data['endpoint']) || batch_protocol
      end

      def batch_protocol_for_endpoint(endpoint)
        case endpoint.to_s.delete_prefix('/')
        when 'v1/responses', 'responses'
          batch_protocol_for_name(:responses)
        when 'v1/chat/completions', 'chat/completions'
          batch_protocol_for_name(:chat_completions)
        when 'v1/embeddings', 'embeddings'
          batch_protocol_for_name(:embeddings)
        end
      end
    end
  end
end
