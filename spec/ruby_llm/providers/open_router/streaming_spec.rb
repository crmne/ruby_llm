# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.describe RubyLLM::Providers::OpenRouter::Streaming do
  include_context 'with configured RubyLLM'

  before do
    RubyLLM.configure do |config|
      config.open_router_api_key = ENV.fetch('OPENROUTER_API_KEY')
    end
  end

  describe 'streaming functionality' do
    # Define test models at the example group level
    before(:all) do
      @test_models = [
        'anthropic/claude-3-opus-20240229',
        'openai/gpt-4-turbo-preview'
      ]
    end

    # Skip live API tests unless explicitly enabled
    before do
      skip "Skipping live API tests" unless ENV['RUN_LIVE_TESTS'] == 'true'
    end

    @test_models&.each do |model|
      context "with #{model}" do
        it 'streams responses in chunks' do
          chunks = []
          chat = RubyLLM.chat(model: model)

          chat.stream("Count from 1 to 3 very slowly.") do |chunk|
            chunks << chunk
          end

          expect(chunks).not_to be_empty
          expect(chunks.first).to be_a(RubyLLM::Chunk)
          expect(chunks.map(&:content).join).to include('1').and include('2').and include('3')
        end

        it 'handles streaming with tools' do
          chunks = []
          chat = RubyLLM.chat(model: model)
          tool = RubyLLM::Tool.new(
            name: 'test_tool',
            description: 'A test tool',
            parameters: {
              type: 'object',
              properties: {
                number: {
                  type: 'integer',
                  description: 'A number to process'
                }
              }
            }
          )

          chat.stream("Use the test tool with number 42.", tools: { test_tool: tool }) do |chunk|
            chunks << chunk
          end

          expect(chunks).not_to be_empty
          expect(chunks.any? { |c| c.tool_calls&.any? }).to be true
        end
      end
    end
  end

  describe 'stream handling' do
    it 'uses the correct stream URL' do
      expect(described_class.stream_url).to eq(described_class.completion_url)
    end

    it 'processes stream data correctly' do
      data = {
        'model' => 'anthropic/claude-3-opus-20240229',
        'choices' => [
          {
            'delta' => {
              'content' => 'test content',
              'tool_calls' => nil
            }
          }
        ]
      }

      chunk = nil
      described_class.to_json_stream do |json_data|
        described_class.handle_stream do |c|
          chunk = c if json_data == data
        end
      end

      expect(chunk).to be_a(RubyLLM::Chunk)
      expect(chunk.content).to eq('test content')
      expect(chunk.model_id).to eq('anthropic/claude-3-opus-20240229')
    end
  end
end 