# frozen_string_literal: true

module RubyLLM
  module Providers
    # Perplexity API integration.
    class Perplexity < Provider
      # Perplexity's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include Perplexity::Chat
        include Perplexity::Embeddings
        include Perplexity::Models
      end

      protocol :chat_completions, ChatCompletions
      protocol :router_chat_completions, Protocols::Perplexity::Router
      protocol :files, Protocols::Perplexity::Files
      protocol :agent_responses, Protocols::Perplexity::Agent

      def api_base
        configured_api_base(:perplexity_api_base, 'https://api.perplexity.ai',
                            endpoints: %r{(?:/router)?(?:/v1)?(?:/chat/completions|/embeddings|/agent)?\z})
      end

      # Chat runs on the Agent API. Embeddings and the model listing stay on
      # the endpoints the Chat Completions dialect knows.
      def protocol_for(model, operation: nil, **)
        operation ? super : protocols[:agent_responses]
      end

      def agent_url # :nodoc:
        "#{api_base}/v1/agent"
      end

      def router_url(operation) # :nodoc:
        "#{api_base}/router/v1/#{operation}"
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.perplexity_api_key}",
          'Content-Type' => 'application/json'
        }
      end

      def parse_error(response)
        body = parse_error_body(response)
        return unless body

        # If response is HTML (Perplexity returns HTML for auth errors)
        if body.is_a?(String) && body.include?('<html>') && body.include?('<title>')
          title_match = body.match(%r{<title>(.+?)</title>})
          if title_match
            message = title_match[1]
            message = message.sub(/^\d+\s+/, '')
            return message
          end
        end
        super
      end

      class << self
        def models_dev_provider_ids # :nodoc:
          %w[perplexity perplexity-agent]
        end

        def configuration_options
          %i[perplexity_api_key perplexity_api_base]
        end

        def configuration_requirements
          %i[perplexity_api_key]
        end
      end
    end
  end
end
