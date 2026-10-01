# frozen_string_literal: true

class CreateRubyLLMProviderFiles < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_llm_provider_files do |t|
      t.string :blob_key, null: false
      t.string :provider, null: false
      t.string :account, null: false
      t.text :file_id, null: false
      t.datetime :expires_at
      t.timestamps

      t.index %i[blob_key provider account], unique: true, name: 'index_ruby_llm_provider_files_uniqueness'
    end
  end
end
