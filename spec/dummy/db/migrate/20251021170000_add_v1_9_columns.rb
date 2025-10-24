# frozen_string_literal: true

class AddV19Columns < ActiveRecord::Migration[7.0]
  def change
    return if column_exists?(:messages, :cached_tokens)

    add_column :messages, :cached_tokens, :integer
    add_column :messages, :cache_creation_tokens, :integer
    add_column :messages, :content_raw, :json
  end
end
