# frozen_string_literal: true

module RubyLLM
  module Providers
    # Cohere API integration.
    class Cohere < Provider
      protocol :cohere, Protocols::Cohere
      protocol :files, Protocols::Cohere::Datasets

      def api_base
        configured_api_base(:cohere_api_base, 'https://api.cohere.com',
                            endpoints: %r{/v[12](?:/chat|/embed|/rerank)?\z})
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.cohere_api_key}"
        }
      end

      class << self
        def models_dev_provider_ids # :nodoc:
          %w[cohere]
        end

        def configuration_options
          %i[cohere_api_key cohere_api_base]
        end

        def configuration_requirements
          %i[cohere_api_key]
        end
      end
    end
  end
end
