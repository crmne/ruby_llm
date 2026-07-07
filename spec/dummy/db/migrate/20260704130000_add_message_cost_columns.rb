# frozen_string_literal: true

class AddMessageCostColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :messages, :total_cost, :decimal, precision: 16, scale: 10 unless column_exists?(:messages, :total_cost)
    add_column :messages, :cost_details, :json unless column_exists?(:messages, :cost_details)
  end
end
