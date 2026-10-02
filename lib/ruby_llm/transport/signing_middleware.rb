# frozen_string_literal: true

require 'faraday'

module RubyLLM
  module Transport # :nodoc:
    # Sits inside Faraday retry middleware so every transport attempt is
    # signed when it is sent, over the body it sends. A signature computed
    # once before the first attempt can expire before a retry goes out.
    class SigningMiddleware < Faraday::Middleware # :nodoc: all
      CONTEXT_KEY = :ruby_llm_signer

      def call(env)
        signer = env.request.context&.[](CONTEXT_KEY)
        sign(env.request_headers, signer.call(env)) if signer
        @app.call(env)
      end

      private

      # A nil value removes a header an earlier attempt was signed with.
      def sign(headers, signed)
        signed.each { |name, value| value.nil? ? headers.delete(name) : headers[name] = value }
      end
    end
  end
end

Faraday::Middleware.register_middleware(llm_signing: RubyLLM::Transport::SigningMiddleware)
