# frozen_string_literal: true

module RubyLLM
  module Providers
    # Hetzner Inference API integration.
    class Hetzner < Provider
      # Hetzner's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include Hetzner::Chat
      end

      protocol :chat_completions, ChatCompletions

      def api_base
        configured_api_base(:hetzner_api_base, 'https://inference.hetzner.com/v1',
                            endpoints: Protocols::ChatCompletions::ENDPOINT_PATHS)
      end

      def headers
        { 'Authorization' => "Bearer #{@config.hetzner_api_key}" }
      end

      class << self
        def models_dev_provider_ids # :nodoc:
          %w[hetzner]
        end

        def configuration_options
          %i[hetzner_api_key hetzner_api_base]
        end

        def configuration_requirements
          %i[hetzner_api_key]
        end

        # Returns +true+: Hetzner Inference is experimental and changes its
        # model selection faster than the registry tracks it, so model ids
        # are accepted as given. Call RubyLLM.models.refresh to pull the
        # live catalog.
        def assume_models_exist?
          true
        end
      end
    end
  end
end
