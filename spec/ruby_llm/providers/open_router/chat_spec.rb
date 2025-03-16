# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.describe RubyLLM::Providers::OpenRouter::Chat do
  include_context 'with configured RubyLLM'

  before do
    RubyLLM.configure do |config|
      config.open_router_api_key = ENV.fetch('OPENROUTER_API_KEY')
    end
  end

  describe 'chat functionality' do
    # Define test models at the example group level
    before(:all) do
      @test_models = [
        'anthropic/claude-3-opus-20240229',
        'openai/gpt-4-turbo-preview',
        'anthropic/claude-3-sonnet-20240229'
      ]
    end

    # Use instance variable in the each loop
    before do
      skip "Skipping live API tests" unless ENV['RUN_LIVE_TESTS'] == 'true'
    end

    @test_models&.each do |model|
      context "with #{model}" do
        it 'can have a basic conversation' do
          chat = RubyLLM.chat(model: model)
          response = chat.ask("What's 2 + 2?")

          expect(response.content).to include('4')
          expect(response.role).to eq(:assistant)
          expect(response.input_tokens).to be_positive
          expect(response.output_tokens).to be_positive
        end

        it 'can handle multi-turn conversations' do
          chat = RubyLLM.chat(model: model)

          first = chat.ask("Who was Ruby's creator?")
          expect(first.content).to include('Matz')

          followup = chat.ask('What year did he create Ruby?')
          expect(followup.content).to include('199')
        end

        it 'supports system messages' do
          chat = RubyLLM.chat(model: model)
          chat.system('You are a helpful assistant that only speaks in haiku.')

          response = chat.ask('Tell me about Ruby programming.')
          expect(response.content).to match(/^\w+.*\n.*\n.*$/) # Rough haiku format check
        end
      end
    end
  end

  describe 'message formatting' do
    it 'formats roles correctly' do
      expect(described_class.format_role(:user)).to eq('user')
      expect(described_class.format_role(:assistant)).to eq('assistant')
      expect(described_class.format_role(:system)).to eq('system')
    end

    it 'raises error for unknown roles' do
      expect { described_class.format_role(:unknown) }.to raise_error(RubyLLM::Error)
    end
  end

  describe 'payload rendering' do
    it 'includes required fields' do
      messages = [RubyLLM::Message.new(role: :user, content: 'Hello')]
      payload = described_class.render_payload(
        messages,
        tools: [],
        temperature: 0.7,
        model: 'anthropic/claude-3-opus-20240229',
        stream: false
      )

      expect(payload[:model]).to eq('anthropic/claude-3-opus-20240229')
      expect(payload[:messages]).to be_an(Array)
      expect(payload[:temperature]).to eq(0.7)
      expect(payload[:stream]).to be false
    end

    it 'includes tools when provided' do
      messages = [RubyLLM::Message.new(role: :user, content: 'Hello')]
      tool = RubyLLM::Tool.new(
        name: 'test_tool',
        description: 'A test tool',
        parameters: { type: 'object', properties: {} }
      )

      payload = described_class.render_payload(
        messages,
        tools: { test_tool: tool },
        temperature: 0.7,
        model: 'anthropic/claude-3-opus-20240229',
        stream: false
      )

      expect(payload[:tools]).to be_an(Array)
      expect(payload[:tool_choice]).to eq('auto')
    end
  end
end 