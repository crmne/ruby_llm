# frozen_string_literal: true

class ToolCall < ApplicationRecord
  include RubyLLM::ActiveRecord::ActsAs
  acts_as_tool_call
end
