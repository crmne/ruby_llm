# frozen_string_literal: true

require 'faraday'

module Benchmarks
  # A Faraday adapter that answers from routes the benchmark registers, so
  # measurements cover RubyLLM and its middleware stack without a network.
  # It reads request bodies the way an adapter writes them to a socket, and
  # hands a streamed response to the stream callback piece by piece.
  class CannedAdapter < Faraday::Adapter
    Request = Struct.new(:verb, :path, :body, :bytes, :stream, keyword_init: true)
    Route = Struct.new(:verb, :pattern, :reply)

    JSON_HEADERS = { 'Content-Type' => 'application/json' }.freeze
    STREAM_HEADERS = { 'Content-Type' => 'text/event-stream; charset=utf-8' }.freeze

    @routes = []

    class << self
      # Answers requests whose path matches +pattern+ with a JSON body, the
      # pieces of a stream, or whatever the block returns for the Request.
      def route(pattern, verb: nil, json: nil, stream: nil, &block)
        reply = block || ->(request) { request.stream ? stream : json }
        @routes.unshift(Route.new(verb, pattern, reply))
      end

      def reset
        @routes.clear
      end

      def reply(request)
        route = @routes.find do |candidate|
          (candidate.verb.nil? || candidate.verb == request.verb) && request.path.match?(candidate.pattern)
        end
        raise "No canned reply for #{request.verb.upcase} #{request.path}" unless route

        route.reply.call(request)
      end
    end

    def call(env)
      super
      body, bytes = consume(env.body)
      request = Request.new(verb: env.method, path: env.url.path, body:, bytes:, stream: env.stream_response?)
      reply = self.class.reply(request)
      request.stream ? stream(env, reply) : save_response(env, 200, reply, JSON_HEADERS.dup)
      @app.call(env)
    end

    private

    def stream(env, pieces)
      save_response(env, 200, nil, nil, 'OK', finished: false) do |headers|
        STREAM_HEADERS.each { |name, value| headers[name] = value }
      end
      env.stream_response { |&on_data| pieces.each { |piece| on_data.call(piece) } }
      env.response_body = ''
      env.response.finish(env)
    end

    def consume(body)
      return [body, body.bytesize] if body.is_a?(String)
      return [nil, 0] unless body.respond_to?(:read)

      bytes = 0
      while (chunk = body.read(16 * 1024))
        bytes += chunk.bytesize
      end
      [nil, bytes]
    end
  end
end
