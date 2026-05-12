# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Streaming do
  include_context 'with configured RubyLLM'

  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(RubyLLM::Providers::OpenAI::Tools)
      obj.extend(described_class)
    end
  end

  describe '#build_chunk' do
    it 'keeps Chat Completions streaming chunks working' do
      chunk = test_obj.send(
        :build_chunk,
        {
          'model' => 'gpt-5-nano',
          'choices' => [
            {
              'delta' => {
                'content' => 'Hello'
              }
            }
          ],
          'usage' => {
            'prompt_tokens' => 10,
            'completion_tokens' => 2,
            'prompt_tokens_details' => { 'cached_tokens' => 4 }
          }
        }
      )

      expect(chunk.content).to eq('Hello')
      expect(chunk.model_id).to eq('gpt-5-nano')
      expect(chunk.input_tokens).to eq(6)
      expect(chunk.cached_tokens).to eq(4)
      expect(chunk.output_tokens).to eq(2)
    end

    it 'builds Responses text delta chunks' do
      chunk = test_obj.send(
        :build_chunk,
        {
          'type' => 'response.output_text.delta',
          'delta' => 'Hi',
          'response' => { 'model' => 'gpt-5.5' }
        }
      )

      expect(chunk.content).to eq('Hi')
      expect(chunk.model_id).to eq('gpt-5.5')
    end

    it 'builds Responses reasoning delta chunks' do
      chunk = test_obj.send(
        :build_chunk,
        {
          'type' => 'response.reasoning_summary_text.delta',
          'delta' => 'thinking'
        }
      )

      expect(chunk.thinking.text).to eq('thinking')
    end

    it 'accumulates Responses function call argument deltas by item id' do
      accumulator = RubyLLM::StreamAccumulator.new

      [
        {
          'type' => 'response.output_item.added',
          'item' => {
            'id' => 'fc_item_123',
            'type' => 'function_call',
            'call_id' => 'call_123',
            'name' => 'weather',
            'arguments' => ''
          }
        },
        {
          'type' => 'response.function_call_arguments.delta',
          'item_id' => 'fc_item_123',
          'delta' => '{"city":"Ky'
        },
        {
          'type' => 'response.function_call_arguments.delta',
          'item_id' => 'fc_item_123',
          'delta' => 'iv"}'
        },
        {
          'type' => 'response.function_call_arguments.done',
          'item_id' => 'fc_item_123',
          'call_id' => 'call_123',
          'name' => 'weather',
          'arguments' => '{"city":"Kyiv"}'
        }
      ].each do |event|
        accumulator.add(test_obj.send(:build_chunk, event))
      end

      message = accumulator.to_message(nil)
      tool_call = message.tool_calls.values.first

      expect(tool_call).to have_attributes(
        id: 'call_123',
        name: 'weather',
        arguments: { 'city' => 'Kyiv' }
      )
    end

    it 'builds Responses completed chunks with usage' do
      chunk = test_obj.send(
        :build_chunk,
        {
          'type' => 'response.completed',
          'response' => {
            'model' => 'gpt-5.5',
            'usage' => {
              'input_tokens' => 20,
              'input_tokens_details' => { 'cached_tokens' => 5 },
              'output_tokens' => 8,
              'output_tokens_details' => { 'reasoning_tokens' => 3 }
            }
          }
        }
      )

      expect(chunk.model_id).to eq('gpt-5.5')
      expect(chunk.input_tokens).to eq(20)
      expect(chunk.cached_tokens).to eq(5)
      expect(chunk.cache_creation_tokens).to eq(0)
      expect(chunk.output_tokens).to eq(8)
      expect(chunk.thinking_tokens).to eq(3)
    end

    it 'raises Responses failed events' do
      expect do
        test_obj.send(
          :build_chunk,
          {
            'type' => 'response.failed',
            'response' => {
              'error' => { 'message' => 'failed' }
            }
          }
        )
      end.to raise_error(RubyLLM::Error, /failed/)
    end
  end

  describe '#parse_streaming_error' do
    it 'parses Responses error payloads' do
      status, message = test_obj.send(
        :parse_streaming_error,
        {
          'type' => 'response.failed',
          'response' => {
            'error' => { 'type' => 'server_error', 'message' => 'failed' }
          }
        }.to_json
      )

      expect(status).to eq(500)
      expect(message).to eq('failed')
    end
  end
end
