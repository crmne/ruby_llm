# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Batch do
  include_context 'with configured RubyLLM'

  describe RubyLLM::Batch::Helpers do
    subject(:helpers) do
      Class.new do
        include RubyLLM::Batch::Helpers

        public :batch_result_index, :batch_failure, :batch_error_message, :single_batch_model!, :batch_payload
      end.new
    end

    describe '#batch_error_message' do
      it 'reads a flat string error' do
        expect(helpers.batch_error_message({ 'error' => 'boom' })).to eq('boom')
      end

      it 'reads every nested shape providers use' do
        expect(helpers.batch_error_message({ 'error' => { 'message' => 'nested' } })).to eq('nested')
        expect(helpers.batch_error_message({ 'error_message' => 'flat field' })).to eq('flat field')
        expect(
          helpers.batch_error_message({ 'response' => { 'body' => { 'error' => { 'message' => 'body' } } } })
        ).to eq('body')
        expect(helpers.batch_error_message({ 'response' => { 'error' => { 'message' => 'response' } } })).to eq(
          'response'
        )
      end

      it 'is nil when the line carries no error' do
        expect(helpers.batch_error_message({})).to be_nil
      end
    end

    describe '#single_batch_model!' do
      it 'returns the one model the requests share' do
        requests = [{ model: 'claude-haiku-4-5' }, { model: 'claude-haiku-4-5' }]

        expect(helpers.single_batch_model!(requests, 'anthropic')).to eq('claude-haiku-4-5')
      end

      it 'refuses a batch that mixes models' do
        requests = [{ model: 'a' }, { model: 'b' }]

        expect { helpers.single_batch_model!(requests, 'anthropic') }.to raise_error(
          RubyLLM::Error, 'anthropic batch requests must use one model per submission'
        )
      end
    end

    describe '#batch_payload' do
      it 'always drops the streaming flag' do
        payload = helpers.batch_payload({ payload: { 'model' => 'a', stream: true } })

        expect(payload).to eq('model' => 'a')
      end

      it 'drops the extra keys the provider asks it to' do
        payload = helpers.batch_payload({ payload: { 'model' => 'a', 'temperature' => 1 } }, except: [:temperature])

        expect(payload).to eq('model' => 'a')
      end
    end

    describe '#batch_result_index' do
      it 'reads the custom id back as an index' do
        expect(helpers.batch_result_index('3')).to eq(3)
      end
    end

    describe '#batch_failure' do
      it 'warns with the detail when there is one' do
        allow(RubyLLM.logger).to receive(:warn)

        helpers.batch_failure('7', 'rate limited', status: 'expired')

        expect(RubyLLM.logger).to have_received(:warn).with('Batch request 7 expired: rate limited')
      end

      it 'warns without a detail' do
        allow(RubyLLM.logger).to receive(:warn)

        helpers.batch_failure('7', nil)

        expect(RubyLLM.logger).to have_received(:warn).with('Batch request 7 failed')
      end
    end
  end

  describe '.find' do
    it 'returns a batch the store already has' do
      persisted = described_class.allocate
      store = Class.new do
        define_method(:fetch) { |_id, **| persisted }
      end.new
      RubyLLM.config.batch_store = store

      expect(described_class.find('msgbatch_123')).to equal(persisted)
    ensure
      RubyLLM.config.batch_store = nil
    end

    it 'refuses a provider that has no batch API' do
      expect { described_class.find('batch_123', provider: :perplexity) }.to raise_error(
        RubyLLM::Error, "perplexity doesn't support batch requests"
      )
    end
  end

  describe '#inspect' do
    it 'shows the id, status and chat count' do
      batch = described_class.new(
        provider: RubyLLM::Providers::Anthropic.new(RubyLLM.config),
        chats: [], id: 'msgbatch_123', status: 'in_progress', completed: false
      )

      expect(batch.inspect).to include('msgbatch_123', 'in_progress')
    end
  end

  describe '#cost' do
    it 'is empty for a batch that collected nothing' do
      batch = described_class.new(
        provider: RubyLLM::Providers::Anthropic.new(RubyLLM.config),
        chats: [], id: 'msgbatch_123', status: 'ended', completed: true
      )
      allow(batch).to receive(:messages).and_return([nil])

      expect(batch.cost.total).to be_nil
    end
  end
end
