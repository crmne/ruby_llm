# frozen_string_literal: true

class AddToolCallSubagentChat < ActiveRecord::Migration[7.1]
  def change
    add_reference :ruby_llm_tool_calls, :subagent_chat, polymorphic: true,
                                                        index: { name: 'index_ruby_llm_tool_calls_on_subagent_chat' }
  end
end
