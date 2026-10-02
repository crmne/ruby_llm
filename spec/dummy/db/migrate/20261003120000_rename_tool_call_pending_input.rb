# frozen_string_literal: true

class RenameToolCallPendingInput < ActiveRecord::Migration[7.1]
  def change
    return unless column_exists?(:ruby_llm_tool_calls, :pending_input)

    rename_column :ruby_llm_tool_calls, :pending_input, :mcp_state
  end
end
