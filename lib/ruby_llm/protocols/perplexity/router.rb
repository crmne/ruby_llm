# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Perplexity
      # Perplexity Router's Chat Completions dialect.
      class Router < ChatCompletions
        def completion_url
          @provider.router_url('chat/completions')
        end

        def render_payload(messages, schema: nil, **)
          super(messages, schema: schema && { strict: true }.merge(schema), **)
        end
      end
    end
  end
end
