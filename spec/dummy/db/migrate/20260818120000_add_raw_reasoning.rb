# frozen_string_literal: true

class AddRawReasoning < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:messages, :raw_reasoning)

    add_column :messages, :raw_reasoning, :json
  end
end
