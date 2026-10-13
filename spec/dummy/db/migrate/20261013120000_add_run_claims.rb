# frozen_string_literal: true

class AddRunClaims < ActiveRecord::Migration[7.1]
  def change
    add_column :chats, :claim_token, :string unless column_exists?(:chats, :claim_token)
    add_column :chats, :claimed_until, :datetime unless column_exists?(:chats, :claimed_until)
    return if column_exists?(:ruby_llm_tool_calls, :claimed_until)

    add_column :ruby_llm_tool_calls, :claimed_until, :datetime
  end
end
