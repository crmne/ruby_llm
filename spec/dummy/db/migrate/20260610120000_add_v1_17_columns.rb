# frozen_string_literal: true

class AddV117Columns < ActiveRecord::Migration[7.0]
  def change
    return if column_exists?(:messages, :citations)

    add_column :messages, :citations, :json
  end
end
