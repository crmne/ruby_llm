# frozen_string_literal: true

require 'active_support/concern'
require 'ruby_llm/active_record/payload_helpers'

module RubyLLM
  module ActiveRecord
    # Methods mixed into tool call models.
    module ToolCallMethods
      extend ActiveSupport::Concern
      include PayloadHelpers

      def message_association
        send(message_association_name)
      end

      def tool_error_message
        payload_error_message(arguments)
      end
    end
  end
end
