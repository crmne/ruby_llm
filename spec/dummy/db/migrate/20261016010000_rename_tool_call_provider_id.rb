# frozen_string_literal: true

class RenameToolCallProviderId < ActiveRecord::Migration[7.1]
  def change
    rename_column :ruby_llm_tool_calls, :provider_id, :provider_call_id
  end
end
