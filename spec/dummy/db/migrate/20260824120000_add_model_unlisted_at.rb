# frozen_string_literal: true

class AddModelUnlistedAt < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:ruby_llm_models, :unlisted_at)

    add_column :ruby_llm_models, :unlisted_at, :datetime
  end
end
