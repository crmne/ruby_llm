# frozen_string_literal: true

require_relative 'streaming/base'
require_relative 'streaming/content'
require_relative 'streaming/messages'
require_relative 'streaming/payload'
require_relative 'streaming/prelude'
require_relative 'streaming/tool_calls'
require_relative 'tools'

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
