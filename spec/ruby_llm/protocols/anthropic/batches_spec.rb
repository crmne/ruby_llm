# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Batches do
  let(:protocol) { RubyLLM::Providers::Anthropic.protocols.fetch(:anthropic).allocate }

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
        raw_status: 'in_progress',
        completed: false,
        request_counts: { 'processing' => 2, 'succeeded' => 0 },
        request_count: 2
      )
    end

    it 'marks ended batches completed' do
      attributes = protocol.send(:parse_batch_response, 'id' => 'msgbatch_123', 'processing_status' => 'ended')

      expect(attributes).to include(completed: true)
    end

    it 'names how an ended batch finished from its request counts' do
      counts = { 'processing' => 0, 'succeeded' => 1, 'errored' => 1, 'canceled' => 0, 'expired' => 0 }
      statuses = [counts, counts.merge('canceled' => 2), counts.merge('expired' => 2)].map do |request_counts|
        protocol.send(:parse_batch_response, 'id' => 'msgbatch_123', 'processing_status' => 'ended',
                                             'request_counts' => request_counts)[:raw_status]
      end

      expect(statuses).to eq(%w[ended canceled expired])
    end
  end

  describe '#create_batch' do
    it 'submits each request under its custom_id with its payload as params' do
      connection = instance_double(RubyLLM::Transport::Connection)
      protocol.instance_variable_set(:@connection, connection)
      allow(connection).to receive(:post).and_return(
        instance_double(Faraday::Response, body: { 'id' => 'msgbatch_1', 'processing_status' => 'in_progress' })
      )

      protocol.create_batch([{ custom_id: '0', payload: { model: 'claude-haiku-4-5' } }])

      expect(connection).to have_received(:post).with(
        'v1/messages/batches', { requests: [{ custom_id: '0', params: { model: 'claude-haiku-4-5' } }] },
        idempotent: false
      )
    end
  end

  describe '#parse_batch_status' do
    it 'succeeds only an ended batch that completed' do
      statuses = [['ended', true], ['ended', false], ['canceling', true]].map do |raw_status, completed|
        protocol.send(:parse_batch_status, raw_status, completed:)
      end

      expect(statuses).to eq(%i[succeeded pending pending])
    end

    it 'tells a cancelled or expired batch from one that succeeded' do
      statuses = %w[canceled expired].map do |raw_status|
        protocol.send(:parse_batch_status, raw_status, completed: true)
      end

      expect(statuses).to eq(%i[cancelled failed])
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
      expect(message.model).to eq('claude-haiku-4-5')
      expect(message.tokens.input).to eq(10)
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

      index, message, status = protocol.send(:parse_batch_result, line)

      expect(index).to eq(0)
      expect(message).to be_nil
      expect(status).to eq(:failed)
      expect(RubyLLM.logger).to have_received(:warn).with(/errored: too long/)
    end

    it 'normalizes canceled request results' do
      line = {
        'custom_id' => '0',
        'result' => { 'type' => 'canceled' }
      }
      allow(RubyLLM.logger).to receive(:warn)

      _index, _message, status = protocol.send(:parse_batch_result, line)

      expect(status).to eq(:cancelled)
    end
  end
end
