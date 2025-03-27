# frozen_string_literal: true

class CreateChats < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :chats do |t|
      t.string :model_id
      t.timestamps
    end
  end
end