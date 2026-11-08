# frozen_string_literal: true

class AddChatClaimedUntilIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :chats, :claimed_until, where: 'claim_token IS NOT NULL'
  end
end
