# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Batches do
  let(:protocol) { RubyLLM::Providers::Gemini.batch_protocols.fetch(:gemini).allocate }

  describe '#gemini_batch_request' do
    it 'wraps rendered GenerateContent params with model and metadata' do
      request = {
        custom_id: '0',
        model: 'gemini-2.5-flash',
        params: {
          contents: [{ role: 'user', parts: [{ text: 'Hi' }] }]
        }
      }

      formatted = protocol.send(:gemini_batch_request, request, 'gemini-2.5-flash')

      expect(formatted).to eq(
        request: {
          contents: [{ role: 'user', parts: [{ text: 'Hi' }] }],
          model: 'models/gemini-2.5-flash'
        },
        metadata: {
          custom_id: '0'
        }
      )
    end
  end

  describe '#create_batch' do
    it 'rejects mixed-model jobs' do
      requests = [
        { model: 'gemini-2.5-flash', params: {} },
        { model: 'gemini-3-flash-preview', params: {} }
      ]

      expect { protocol.create_batch(requests) }
        .to raise_error(RubyLLM::Error, /one model/)
    end
  end

  describe '#parse_batch_response' do
    it 'reads the state from the operation that create returns' do
      data = { 'name' => 'batches/abc', 'metadata' => { 'state' => 'JOB_STATE_PENDING' } }

      expect(protocol.send(:parse_batch_response, data)).to include(
        id: 'batches/abc', status: 'JOB_STATE_PENDING', completed: false
      )
    end

    it 'reads the state from the batch that polling returns' do
      data = { 'name' => 'batches/abc', 'state' => 'BATCH_STATE_RUNNING', 'batchStats' => { 'requestCount' => '2' } }

      expect(protocol.send(:parse_batch_response, data)).to include(
        id: 'batches/abc', status: 'BATCH_STATE_RUNNING', completed: false,
        request_counts: { 'requestCount' => '2' }
      )
    end

    it 'marks terminal states completed regardless of the enum prefix' do
      states = %w[BATCH_STATE_SUCCEEDED JOB_STATE_SUCCEEDED JOB_STATE_FAILED JOB_STATE_CANCELLED JOB_STATE_EXPIRED]
      states.each do |state|
        expect(protocol.send(:parse_batch_response, 'name' => 'batches/abc', 'state' => state))
          .to include(completed: true)
      end
    end
  end

  describe '#parse_inline_response' do
    it 'parses a succeeded response keyed by the metadata custom id' do
      inline = {
        'metadata' => { 'custom_id' => '1' },
        'response' => {
          'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Jupiter' }] } }],
          'modelVersion' => 'gemini-2.5-flash',
          'usageMetadata' => { 'promptTokenCount' => 5, 'candidatesTokenCount' => 3 }
        }
      }

      index, message = protocol.send(:parse_inline_response, inline, 0)

      expect(index).to eq(1)
      expect(message.content).to eq('Jupiter')
      expect(message.model_id).to eq('gemini-2.5-flash')
      expect(message.input_tokens).to eq(5)
    end

    it 'falls back to the old metadata key and then position' do
      inline = { 'metadata' => { 'key' => '2' }, 'response' => { 'candidates' => [] } }
      expect(protocol.send(:parse_inline_response, inline, 0).first).to eq(2)

      inline = { 'response' => { 'candidates' => [] } }
      expect(protocol.send(:parse_inline_response, inline, 3).first).to eq(3)
    end

    it 'logs and skips a per-item error' do
      inline = { 'metadata' => { 'custom_id' => '0' }, 'error' => { 'code' => 400, 'message' => 'too long' } }
      allow(RubyLLM.logger).to receive(:warn)

      index, message = protocol.send(:parse_inline_response, inline, 0)

      expect(index).to eq(0)
      expect(message).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/failed: too long/)
    end
  end
end
