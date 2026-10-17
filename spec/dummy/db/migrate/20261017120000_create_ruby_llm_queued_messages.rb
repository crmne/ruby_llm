# frozen_string_literal: true

class CreateRubyLLMQueuedMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_llm_queued_messages do |t|
      t.references :chat, polymorphic: true, null: false, index: false
      t.references :owner, polymorphic: true, index: false
      t.text :content
      t.boolean :steer, default: true, null: false
      t.timestamps

      t.index %i[chat_type chat_id]
      t.index %i[owner_type owner_id]
    end
  end
end
