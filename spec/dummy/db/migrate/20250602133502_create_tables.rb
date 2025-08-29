# frozen_string_literal: true

class CreateTables < ActiveRecord::Migration[7.0]
  def change
    # Create models table first (for foreign key references)
    create_table :models do |t|
      t.string :model_id, null: false
      t.string :name, null: false
      t.string :provider, null: false
      t.string :family
      t.datetime :model_created_at
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :knowledge_cutoff
      t.json :modalities, default: {}
      t.json :capabilities, default: []
      t.json :pricing, default: {}
      t.json :metadata, default: {}
      t.timestamps

      t.index %i[provider model_id], unique: true
      t.index :provider
      t.index :family
    end

    create_table :chats do |t|
      t.references :model, foreign_key: true
      t.timestamps
    end

    create_table :messages do |t|
      t.references :chat
      t.string :role
      t.text :content
      t.references :model, foreign_key: true
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
