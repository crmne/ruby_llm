# frozen_string_literal: true

class AddMessageCacheTtl < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :cache_ttl, :string unless column_exists?(:messages, :cache_ttl)
  end
end
