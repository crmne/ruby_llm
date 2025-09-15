# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Streaming implementation for the AWS Bedrock API.
      module Streaming
        include Base
      end
    end
  end
end
