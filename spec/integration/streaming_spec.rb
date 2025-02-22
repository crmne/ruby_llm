# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.describe 'Tools Integration' do # rubocop:disable Metrics/BlockLength
  before(:all) do
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch('OPENAI_API_KEY')
      config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY')
      config.gemini_api_key = ENV.fetch('GEMINI_API_KEY')
    end
  end

  class Calculator < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock
    description 'Performs basic arithmetic'

    param :expression,
          type: :string,
          desc: 'Math expression to evaluate'

    def execute(expression:)
      eval(expression).to_s # rubocop:disable Security/Eval
    rescue StandardError => e
      "Error: #{e.message}"
    end
  end

  describe 'streaming responses' do # rubocop:disable Metrics/BlockLength
    ['claude-3-5-sonnet-20241022', 'gemini-2.0-flash', 'gpt-4o-mini'].each do |model| # rubocop:disable Metrics/BlockLength
      context "with #{model}" do # rubocop:disable Metrics/BlockLength
        it 'supports streaming responses' do
          chat = RubyLLM.chat(model: model)
          chunks = []

          chat.ask('Count from 1 to 3') do |chunk|
            chunks << chunk
          end

          expect(chunks).not_to be_empty
          expect(chunks.first).to be_a(RubyLLM::Chunk)
        end

        it 'can use tools with multi-turn streaming responses' do
          chat = RubyLLM.chat(model: model)
                        .with_tool(Calculator)
          chunks = []

          response = chat.ask("What's 123 * 456?") do |chunk|
            chunks << chunk
          end

          expect(chunks).not_to be_empty
          expect(chunks.first).to be_a(RubyLLM::Chunk)
          expect(response.content).to include(/56(,?)088/)

          response = chat.ask("What's 456 divided by 123?") do |chunk|
            chunks << chunk
          end

          expect(chunks).not_to be_empty
          expect(chunks.first).to be_a(RubyLLM::Chunk)
          expect(response.content).to include('3')
        end
      end
    end
  end
end
