# frozen_string_literal: true

class RenameCacheTokenColumns < ActiveRecord::Migration[7.0]
  def change
    return unless column_exists?(:messages, :cached_tokens)

    rename_column :messages, :cached_tokens, :cache_read_tokens
    rename_column :messages, :cache_creation_tokens, :cache_write_tokens
  end
end
