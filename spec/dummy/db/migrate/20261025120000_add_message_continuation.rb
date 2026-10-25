# frozen_string_literal: true

class AddMessageContinuation < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :continuation, :text unless column_exists?(:messages, :continuation)
  end
end
