# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:fixtures) { File.expand_path('../../fixtures/skills', __dir__) }

  before { RubyLLM::Skill.roots << fixtures }
  after { RubyLLM::Skill.instance_variable_set(:@roots, nil) }

  it 'lists the skills in each request without storing the listing' do
    chat = Chat.create!(model: model_for(:anthropic), provider: :anthropic)
    expect(chat.with_skills(:ticket_codes)).to be(chat)
    call = RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: 'load_skill',
                                 arguments: { 'skill' => 'ticket-codes' })
    sent = []
    allow(chat.to_llm.provider).to receive(:complete) do |messages, **|
      sent << messages
      next RubyLLM::Message.new(role: :assistant, content: 'TKT-42-ZX') unless sent.one?

      RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call })
    end

    chat.ask('Ticket code for 6?')
    stored = Chat.find(chat.id).messages

    expect(chat.skills.map(&:name)).to eq(['ticket-codes'])
    expect(sent.last.first.content).to include('- ticket-codes: Builds the official code')
    expect(stored.map(&:role)).to eq(%w[user assistant tool assistant])
    expect(stored.find_by(role: 'tool').content).to include('# Ticket codes')
    expect(stored.pluck(:content).join).not_to include('<skills>')
  end
end
