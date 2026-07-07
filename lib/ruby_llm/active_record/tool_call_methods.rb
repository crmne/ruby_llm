# frozen_string_literal: true

require 'active_support/concern'
require 'ruby_llm/active_record/payload_helpers'

module RubyLLM
  module ActiveRecord
    # ToolCallMethods holds the instance methods that
    # <tt>acts_as_tool_call</tt> mixes into a tool call model.
    #
    #   class ToolCall < ApplicationRecord
    #     acts_as_tool_call
    #   end
    #
    module ToolCallMethods
      extend ActiveSupport::Concern
      include PayloadHelpers

      def message_association # :nodoc:
        send(message_association_name)
      end

      # Returns the error message recorded in the tool call's +arguments+
      # payload, or +nil+ when there is none. The views created by the
      # tool generator use it to render failed tool calls.
      def tool_error_message
        payload_error_message(arguments)
      end
    end
  end
end
