# frozen_string_literal: true

class CreateRubyLLMMcpCredentials < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_llm_mcp_credentials do |t|
      t.references :owner, polymorphic: true
      t.string :key, null: false
      t.text :data
      t.timestamps

      t.index :key, unique: true
    end
  end
end
