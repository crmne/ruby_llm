# frozen_string_literal: true

class AddToolCallApproval < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:ruby_llm_tool_calls, :approval)

    add_column :ruby_llm_tool_calls, :approval, :string
  end
end
