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
