# frozen_string_literal: true

# This migration must be run AFTER create_chats and create_tool_calls migrations
# to ensure proper foreign key references
class CreateMessages < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :role
      t.text :content
      t.string :model_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.references :tool_call, foreign_key: true
      t.timestamps
    end
  end
end