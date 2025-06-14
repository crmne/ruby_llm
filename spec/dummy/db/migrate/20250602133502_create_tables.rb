# frozen_string_literal: true

class CreateTables < ActiveRecord::Migration[7.0]
  def change
    create_table :chats do |t|
      t.string :model_id
      t.timestamps
    end

    create_table :messages do |t|
      t.references :chat
      t.string :role
      t.text :content
      t.string :model_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.references :tool_call
      t.timestamps
    end

    create_table :tool_calls do |t|
      t.references :message
      t.string :tool_call_id
      t.string :name
      t.json :arguments
      t.timestamps
    end
  end
end
