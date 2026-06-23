# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Batches do
  let(:protocol) { RubyLLM::Providers::Anthropic.batch_protocols.fetch(:anthropic).allocate }

  describe '#parse_batch_response' do
    it 'normalizes the batch attributes' do
      data = {
        'id' => 'msgbatch_123',
        'processing_status' => 'in_progress',
        'request_counts' => { 'processing' => 2, 'succeeded' => 0 }
      }

      attributes = protocol.send(:parse_batch_response, data)

      expect(attributes).to eq(
        id: 'msgbatch_123',
        status: 'in_progress',
        completed: false,
        request_counts: { 'processing' => 2, 'succeeded' => 0 }
      )
    end

    it 'marks ended batches completed' do
      attributes = protocol.send(:parse_batch_response, 'id' => 'msgbatch_123', 'processing_status' => 'ended')

      expect(attributes).to include(completed: true)
    end
  end

  describe '#parse_batch_result' do
    it 'parses succeeded results into messages keyed by submission index' do
      line = {
        'custom_id' => '1',
        'result' => {
          'type' => 'succeeded',
          'message' => {
            'content' => [{ 'type' => 'text', 'text' => 'Jupiter' }],
            'model' => 'claude-haiku-4-5',
            'usage' => { 'input_tokens' => 10, 'output_tokens' => 2 }
          }
        }
      }

      index, message = protocol.send(:parse_batch_result, line)

      expect(index).to eq(1)
      expect(message.content).to eq('Jupiter')
      expect(message.model_id).to eq('claude-haiku-4-5')
      expect(message.input_tokens).to eq(10)
    end

    it 'logs and skips failed results' do
      line = {
        'custom_id' => '0',
        'result' => {
          'type' => 'errored',
          'error' => { 'type' => 'error', 'error' => { 'type' => 'invalid_request_error', 'message' => 'too long' } }
        }
      }
      allow(RubyLLM.logger).to receive(:warn)

      index, message = protocol.send(:parse_batch_result, line)

      expect(index).to eq(0)
      expect(message).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/errored: too long/)
    end
  end
end
