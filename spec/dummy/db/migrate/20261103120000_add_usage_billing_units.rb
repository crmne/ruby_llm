# frozen_string_literal: true

class AddUsageBillingUnits < ActiveRecord::Migration[7.1]
  def change
    change_table :ruby_llm_usages, bulk: true do |t|
      t.integer :characters
      t.decimal :audio_seconds, precision: 16, scale: 6
      t.integer :search_units
      t.decimal :characters_cost, precision: 16, scale: 10
      t.decimal :audio_seconds_cost, precision: 16, scale: 10
      t.decimal :search_units_cost, precision: 16, scale: 10
    end
  end
end
