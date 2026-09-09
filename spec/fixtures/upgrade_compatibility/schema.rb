# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :models do |table|
    table.string :model_id, null: false
    table.string :name, null: false
    table.string :provider, null: false
    table.string :family
    table.datetime :model_created_at
    table.integer :context_window
    table.integer :max_output_tokens
    table.date :knowledge_cutoff
    table.json :modalities, default: {}
    table.json :capabilities, default: []
    table.json :pricing, default: {}
    table.json :metadata, default: {}
    table.timestamps
    table.index %i[provider model_id], unique: true
  end

  create_table :chats do |table|
    table.string :title
    table.timestamps
  end

  create_table :messages do |table|
    table.string :role, null: false
    table.text :content
    table.json :content_raw
    table.text :thinking_text
    table.text :thinking_signature
    table.integer :thinking_tokens
    table.integer :input_tokens
    table.integer :output_tokens
    table.integer :cached_tokens
    table.integer :cache_creation_tokens
    table.timestamps
  end

  create_table :tool_calls do |table|
    table.string :tool_call_id, null: false
    table.string :name, null: false
    table.text :thought_signature
    table.json :arguments, default: {}
    table.timestamps
    table.index :tool_call_id, unique: true
  end

  add_reference :chats, :model, foreign_key: true
  add_reference :tool_calls, :message, null: false, foreign_key: true
  add_reference :messages, :chat, null: false, foreign_key: true
  add_reference :messages, :model, foreign_key: true
  add_reference :messages, :tool_call, foreign_key: true
end
