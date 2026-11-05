# frozen_string_literal: true

class AddChatFileReadDigest < ActiveRecord::Migration[7.1]
  def change
    add_column :ruby_llm_chat_files, :read_digest, :string
  end
end
