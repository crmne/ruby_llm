# frozen_string_literal: true

class AddToolCallPendingInput < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:ruby_llm_tool_calls, :pending_input)

    add_column :ruby_llm_tool_calls, :pending_input, :json
  end
end
