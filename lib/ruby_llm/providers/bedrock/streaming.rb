# frozen_string_literal: true

require_relative 'streaming/base'
require_relative 'streaming/content_extraction'
require_relative 'streaming/message_processing'
require_relative 'streaming/payload_processing'
require_relative 'streaming/prelude_handling'

module RubyLLM
  module Providers
    module Bedrock
      # Streaming implementation for the AWS Bedrock API.
      # This module provides functionality for handling streaming responses from AWS Bedrock,
      # including message processing, content extraction, and error handling.
      #
      # The implementation is split into several focused modules:
      # - Base: Core streaming functionality and module coordination
      # - ContentExtraction: Extracting content from response data
      # - MessageProcessing: Processing streaming message chunks
      # - PayloadProcessing: Handling JSON payloads and chunk creation
      # - PreludeHandling: Managing message preludes and headers
      #
      # @example Using the streaming module
      #   class BedrockClient
      #     include RubyLLM::Providers::Bedrock::Streaming
      #
      #     def stream_response(&block)
      #       handle_stream(&block)
      #     end
      #   end
      module Streaming
        include Base
      end
    end
  end
end
