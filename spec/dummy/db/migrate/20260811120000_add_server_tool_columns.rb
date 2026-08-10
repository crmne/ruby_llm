# frozen_string_literal: true

class AddServerToolColumns < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:messages, :server_tool_calls)

    add_column :messages, :server_tool_calls, :json
    add_column :messages, :raw_content, :json
  end
end
