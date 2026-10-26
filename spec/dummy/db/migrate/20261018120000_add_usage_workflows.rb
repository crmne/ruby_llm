# frozen_string_literal: true

class AddUsageWorkflows < ActiveRecord::Migration[7.1]
  def change
    %i[workflow_id workflow_name workflow_step_id workflow_step_name].each do |column|
      add_column :ruby_llm_usages, column, :string unless column_exists?(:ruby_llm_usages, column)
    end
    add_index :ruby_llm_usages, :workflow_id unless index_exists?(:ruby_llm_usages, :workflow_id)
  end
end
