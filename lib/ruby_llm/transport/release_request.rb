# frozen_string_literal: true

require 'faraday'

module RubyLLM
  module Transport
    # Sits outside everything on a connection without retries, so an error
    # leaves it without the credentials of the request it answers.
    class ReleaseRequest < Faraday::Middleware # :nodoc:
      # The response outlives the call as Message#raw, Error#response, and
      # other results, which applications log and report. The request holds
      # the API key in its headers, the whole serialized conversation in its
      # body, and the provider and signer in its context, and a streaming
      # callback closes over the payload it was built from.
      def self.release(response)
        response.delete(:request) if response.is_a?(Hash)
        env = response.respond_to?(:env) ? response.env : response
        return response unless env.is_a?(Faraday::Env)

        env.request_body = nil
        env.request_headers = Faraday::Utils::Headers.new
        # A response built by hand, such as one a protocol attaches to the
        # error it raises, has no request options to clear.
        if env.request
          env.request.on_data = nil
          env.request.context = nil
        end
        response
      end

      def call(env)
        @app.call(env)
      rescue Error, Faraday::Error => e
        self.class.release(e.response)
        raise
      end
    end
  end
end
