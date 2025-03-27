# frozen_string_literal: true

# Migration for creating tool_calls table with database-specific JSON handling
class CreateToolCalls < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :tool_calls do |t|
      # No reference to message to avoid circular references
      # Messages will reference tool_calls, not the other way around
      t.string :tool_call_id, null: false
      t.string :name, null: false
      
      # Use the appropriate JSON column type for the database
      if postgresql?
        t.jsonb :arguments, default: {}
      else
        t.json :arguments, default: {}
      end
      
      t.timestamps
    end

    add_index :tool_calls, :tool_call_id
  end
end