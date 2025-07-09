# frozen_string_literal: true

module RubyLLM
  module Providers
    module AzureOpenAI
      # Streaming methods of the OpenAI API integration
      module Streaming
        extend OpenAI::Streaming

        module_function

        def stream_response(connection, payload, &block)
          # Hold config in instance variable for use in completion_url and stream_url
          @config = connection.config
          super
        end
      end
    end
  end
end
