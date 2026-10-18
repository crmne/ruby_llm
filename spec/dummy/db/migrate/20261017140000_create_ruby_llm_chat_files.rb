# frozen_string_literal: true

class CreateRubyLLMChatFiles < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_llm_chat_files do |t|
      t.references :chat, polymorphic: true, null: false, index: false
      t.references :owner, polymorphic: true, index: false
      t.string :path, null: false
      t.string :content_type
      t.bigint :byte_size
      t.string :digest
      t.text :text
      t.timestamps

      t.index %i[chat_type chat_id path]
      t.index %i[owner_type owner_id]
    end
  end
end
