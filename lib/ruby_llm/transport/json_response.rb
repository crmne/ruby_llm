# frozen_string_literal: true

require 'faraday'
require 'json'

module RubyLLM
  module Transport
    class JsonResponse < Faraday::Middleware # :nodoc:
      RAW_KEY = :ruby_llm_raw_body

      def initialize(app, parser_options: {}, preserve_raw: false)
        super(app)
        @parser_options = parser_options || {}
        @preserve_raw = preserve_raw
      end

      def on_complete(env)
        body = env[:body]
        return unless body.respond_to?(:to_str) && json_response?(env) && !raw?(env)

        env[:raw_body] = body if @preserve_raw
        env[:body] = body.strip.empty? ? nil : JSON.parse(body, **@parser_options)
      rescue StandardError, SyntaxError => e
        raise Faraday::ParsingError.new(e, env[:response])
      end

      private

      def raw?(env)
        env[:request]&.context&.dig(RAW_KEY)
      end

      def json_response?(env)
        content_type = env[:response_headers]['content-type'].to_s.split(';', 2).first
        content_type&.match?(/\bjson$/)
      end
    end
  end
end
