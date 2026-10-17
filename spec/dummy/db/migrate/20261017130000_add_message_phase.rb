# frozen_string_literal: true

class AddMessagePhase < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :phase, :string unless column_exists?(:messages, :phase)
  end
end
