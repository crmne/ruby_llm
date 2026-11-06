# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs, :live do
  let(:question) { 'Search the web: what is the latest stable Ruby version? Answer in one sentence.' }

  {
    openai: :reasoning_effort, anthropic: :chat, gemini: :provider_tools
  }.each do |provider, purpose|
    it "restores the #{provider} web sources from the record" do
      chat = Chat.create!(model: model_for(provider, purpose), provider:)
      response = chat.with_provider_tools(:web_search).ask(question)
      record = Message.find(chat.messages.last.id)

      expect(response.web_sources).not_to be_empty
      expect(record.web_sources.map(&:to_h)).to eq(response.web_sources.map(&:to_h))
    end
  end
end
