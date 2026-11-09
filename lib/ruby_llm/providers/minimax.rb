# frozen_string_literal: true

module RubyLLM
  module Providers
    # MiniMax API integration, through its Anthropic-compatible endpoint.
    class MiniMax < Provider
      protocol :anthropic, MiniMax::Anthropic
      protocol :media, Protocols::MiniMax
      protocol :files, Protocols::MiniMax::Files

      MEDIA_OPERATIONS = %i[paint animate speak transcribe].freeze

      # The HTTP status each MiniMax status code stands for on endpoints that
      # answer 200 and report the failure in base_resp.
      FAILURE_STATUSES = {
        1000 => 500, 1001 => 504, 1002 => 429, 1004 => 401, 1008 => 402, 1039 => 429, 2049 => 401, 2056 => 429
      }.freeze

      def resolve_protocol(name, model, operation: nil, **options)
        name ||= :media if MEDIA_OPERATIONS.include?(operation)
        super
      end

      def api_base
        configured_api_base(:minimax_api_base, 'https://api.minimax.io/anthropic', endpoints: %r{/v1/messages\z})
      end

      def media_base # :nodoc:
        api_base.sub(%r{/anthropic/?\z}, '')
      end

      def headers
        { 'Authorization' => "Bearer #{@config.minimax_api_key}" }
      end

      def account_identity
        account_digest(api_base, @config.minimax_api_key)
      end

      def error_status(response)
        code = failure_code(response)
        FAILURE_STATUSES.fetch(code, 400) if code
      end

      def parse_error(response)
        return super unless failure_code(response)

        parse_error_body(response).dig('base_resp', 'status_msg')
      end

      class << self
        def models_dev_provider_ids # :nodoc:
          %w[minimax]
        end

        def configuration_options
          %i[minimax_api_key minimax_api_base]
        end

        def configuration_requirements
          %i[minimax_api_key]
        end
      end

      private

      def failure_code(response)
        return unless response.body.to_s.include?('base_resp')

        body = parse_error_body(response)
        code = body.dig('base_resp', 'status_code') if body.is_a?(Hash)
        code unless code.nil? || code.zero?
      end
    end
  end
end
