# frozen_string_literal: true

class AddChatPermissions < ActiveRecord::Migration[7.1]
  def change
    add_column :chats, :permissions, :string unless column_exists?(:chats, :permissions)
    add_column :chats, :permission_grants, :json unless column_exists?(:chats, :permission_grants)
  end
end
