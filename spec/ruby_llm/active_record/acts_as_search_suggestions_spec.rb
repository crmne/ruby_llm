# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs, :live do
  let(:model) { model_for(:gemini, :provider_tools) }
  let(:question) { 'Search the web: what is the latest stable Ruby version? Answer in one sentence.' }
  let(:suggestion_markers) { %w[gradient-container app-vertex-grounding searchEntryPoint search_suggestions] }

  def stored_text(chat)
    messages = Message.where(chat_id: chat.id)
    [
      Chat.where(id: chat.id), messages, RubyLLM::ActiveRecord::Usage.where(chat:),
      RubyLLM::ActiveRecord::ToolCall.where(message_type: 'Message', message_id: messages.select(:id))
    ].map { |rows| rows.connection.select_all(rows.to_sql).rows.flatten.join(' ') }.join(' ')
  end

  it 'shows Gemini search suggestions on the live answer without storing them' do
    chat = Chat.create!(model:, provider: :gemini)
    response = chat.with_provider_tools(:web_search).ask(question)
    suggestions = response.server_tool_calls.filter_map(&:search_suggestions).join

    expect(suggestions).to include('gradient-container', 'app-vertex-grounding')
    expect(stored_text(chat)).not_to include(*suggestion_markers)
    expect(Message.find(chat.messages.last.id).server_tool_calls.map(&:search_suggestions)).to all(be_nil)
  end
end
