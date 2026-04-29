# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Methods mixed into tool call models.
    module ToolCallMethods
      extend ActiveSupport::Concern
      include PayloadHelpers

      def tool_error_message
        payload_error_message(arguments)
      end
    end
  end
end
