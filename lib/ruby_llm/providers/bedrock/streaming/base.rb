# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      module Streaming
        # Base module for AWS Bedrock streaming functionality.
        # Serves as the core module that includes all other streaming-related modules
        # and provides fundamental streaming operations.
        #
        # Responsibilities:
        # - Stream URL management
        # - Stream handling and error processing
        # - Coordinating the functionality of other streaming modules
        #
        # @example
        #   module MyStreamingImplementation
        #     include RubyLLM::Providers::Bedrock::Streaming::Base
        #   end
        module Base
          def self.included(base)
            base.include ContentExtraction
            base.include MessageProcessing
            base.include PayloadProcessing
            base.include PreludeHandling
          end

          def stream_url
            "model/#{@model_id}/invoke-with-response-stream"
          end

          def stream_response(connection, payload, &block)
            signature = sign_request("#{connection.connection.url_prefix}#{stream_url}", config: connection.config,
                                                                                         payload:)
            accumulator = StreamAccumulator.new

            connection.post stream_url, payload do |req|
              req.headers.merge! build_headers(signature.headers, streaming: block_given?)
              req.options.on_data = handle_stream do |chunk|
                accumulator.add chunk
                block.call chunk
              end
            end

            accumulator.to_message
          end

          def handle_stream(&block)
            buffer = String.new
            proc do |chunk, _bytes, env|
              if env && env.status != 200
                handle_failed_response(chunk, buffer, env)
              else
                process_chunk(chunk, &block)
              end
            end
          end
        end
      end
    end
  end
end
