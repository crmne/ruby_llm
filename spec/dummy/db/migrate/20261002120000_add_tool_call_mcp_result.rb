# frozen_string_literal: true

class AddToolCallMcpResult < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:ruby_llm_tool_calls, :mcp_result)

    add_column :ruby_llm_tool_calls, :mcp_result, :json
  end
end
