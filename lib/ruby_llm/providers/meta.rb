# frozen_string_literal: true

module RubyLLM
  module Providers
    # Meta Model API integration for the Muse models.
    class Meta < Provider
      protocol :responses, Meta::Responses

      def api_base
        @config.meta_api_base || 'https://api.meta.ai/v1'
      end

      def headers
        { 'Authorization' => "Bearer #{@config.meta_api_key}" }
      end

      def account_identity
        account_digest(api_base, @config.meta_api_key)
      end

      class << self
        def configuration_options
          %i[meta_api_key meta_api_base]
        end

        def configuration_requirements
          %i[meta_api_key]
        end
      end
    end
  end
end
