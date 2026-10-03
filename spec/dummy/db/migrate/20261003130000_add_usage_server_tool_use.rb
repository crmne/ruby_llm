# frozen_string_literal: true

class AddUsageServerToolUse < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:ruby_llm_usages, :server_tool_use)

    add_column :ruby_llm_usages, :server_tool_use, :json
  end
end
