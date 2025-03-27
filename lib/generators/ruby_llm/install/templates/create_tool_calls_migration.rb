# frozen_string_literal: true

class CreateToolCalls < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :tool_calls do |t|
      t.references :message, null: false, foreign_key: true
      t.string :tool_call_id, null: false
      t.string :name, null: false
      t.jsonb :arguments, default: {}
      t.timestamps
    end

    add_index :tool_calls, :tool_call_id
  end
end