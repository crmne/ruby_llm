# frozen_string_literal: true

class AddUsageOwner < ActiveRecord::Migration[7.1]
  def change
    if columns(:ruby_llm_usages).any? { |column| column.name == 'chat_id' && !column.null }
      change_column_null :ruby_llm_usages, :chat_type, true
      change_column_null :ruby_llm_usages, :chat_id, true
    end

    return if column_exists?(:ruby_llm_usages, :owner_id)

    add_reference :ruby_llm_usages, :owner, polymorphic: true, index: true
  end
end
