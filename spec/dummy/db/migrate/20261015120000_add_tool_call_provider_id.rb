# frozen_string_literal: true

class AddToolCallProviderId < ActiveRecord::Migration[7.1]
  def change
    add_column :ruby_llm_tool_calls, :provider_id, :string
  end
end
