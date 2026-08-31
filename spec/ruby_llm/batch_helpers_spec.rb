# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Batch do
  include_context 'with configured RubyLLM'

  describe '#status' do
    it 'normalizes provider lifecycle statuses' do
      cases = [
        [:anthropic, 'in_progress', false, :pending],
        [:anthropic, 'ended', true, :succeeded],
        [:openai, 'failed', true, :failed],
        [:openai, 'expired', true, :failed],
        [:openai, 'cancelled', true, :cancelled],
        [:gemini, 'JOB_STATE_SUCCEEDED', true, :succeeded],
        [:gemini, 'JOB_STATE_FAILED', true, :failed],
        [:gemini, 'JOB_STATE_CANCELLED', true, :cancelled],
        [:mistral, 'TIMEOUT_EXCEEDED', true, :failed],
        [:mistral, 'CANCELLED', true, :cancelled],
        [:bedrock, 'PartiallyCompleted', true, :succeeded],
        [:bedrock, 'Stopped', true, :cancelled],
        [:vertexai, 'JOB_STATE_PARTIALLY_SUCCEEDED', true, :succeeded],
        [:vertexai, 'JOB_STATE_EXPIRED', true, :failed],
        [:xai, 'completed', true, :succeeded]
      ]

      cases.each do |provider_name, raw_status, completed, status|
        provider = RubyLLM::Provider.resolve!(provider_name).new(RubyLLM.config)
        batch = described_class.new(provider:, id: 'batch_1', raw_status:, completed:)

        expect(batch.status).to eq(status), "expected #{provider_name} #{raw_status} to be #{status}"
      end
    end

    it 'exposes the provider status separately' do
      provider = RubyLLM::Provider.resolve!(:openai).new(RubyLLM.config)
      batch = described_class.new(provider:, id: 'batch_1', raw_status: 'cancelled', completed: true)

      expect(batch.status).to eq(:cancelled)
      expect(batch.raw_status).to eq('cancelled')
      expect(batch).to be_complete
      expect(batch).to be_cancelled
      expect(batch).not_to be_succeeded
      expect(batch).not_to be_failed
    end
  end

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

      it 'reads nested string errors' do
        expect(helpers.batch_error_message({ 'response' => { 'body' => { 'error' => 'body' } } })).to eq('body')
        expect(helpers.batch_error_message({ 'response' => { 'error' => 'response' } })).to eq('response')
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
    # The batch store is global configuration, and the Rails integration
    # installs one at boot; hand back whatever was there.
    around do |example|
      store = RubyLLM.config.batch_store
      example.run
    ensure
      RubyLLM.config.batch_store = store
    end

    it 'returns a batch the store already has' do
      persisted = described_class.allocate
      store = Class.new do
        define_method(:fetch) { |_id, **| persisted }
      end.new
      RubyLLM.config.batch_store = store

      expect(described_class.find('msgbatch_123')).to equal(persisted)
    end

    it 'refuses a provider that has no batch API' do
      expect { described_class.find('batch_123', provider: :perplexity) }.to raise_error(
        RubyLLM::Error, "perplexity doesn't support batch requests"
      )
    end
  end

  describe '#messages' do
    it 'delivers an answer once even when the chat stages another question' do
      chat = RubyLLM.chat(model: 'claude-haiku-4-5').ask_later('First question')
      provider = chat.provider
      answer = RubyLLM::Message.new(role: :assistant, content: 'First answer', input_tokens: 1, output_tokens: 1)
      allow(provider).to receive(:batch_results).and_return([[0, answer]])
      batch = described_class.new(
        provider:, chats: [chat], id: 'msgbatch_123', raw_status: 'in_progress', completed: false
      )

      batch.messages
      chat.ask_later('Second question')

      expect { batch.messages }.not_to change(chat, :messages)
      expect(chat.messages.map(&:role)).to eq(%i[user assistant user])
    end

    it 'retains every missing slot when a reloaded provider batch fails' do
      provider = RubyLLM::Provider.resolve!(:openai).new(RubyLLM.config)
      allow(provider).to receive(:batch_results).and_return([])
      batch = described_class.new(
        provider:,
        id: 'batch_1',
        raw_status: 'failed',
        completed: true,
        request_count: 3,
        request_counts: { 'total' => 3 }
      )

      expect(batch.messages).to eq([nil, nil, nil])
      expect(batch.statuses).to eq(%i[failed failed failed])
    end

    it 'marks unreturned slots cancelled on a cancelled provider batch' do
      provider = RubyLLM::Provider.resolve!(:openai).new(RubyLLM.config)
      allow(provider).to receive(:batch_results).and_return([])
      batch = described_class.new(
        provider:,
        id: 'batch_1',
        raw_status: 'cancelled',
        completed: true,
        request_count: 2,
        request_counts: { total: 2 }
      )

      expect(batch.messages).to eq([nil, nil])
      expect(batch.statuses).to eq(%i[cancelled cancelled])
    end
  end

  describe '#inspect' do
    it 'shows the id, status and chat count' do
      batch = described_class.new(
        provider: RubyLLM::Providers::Anthropic.new(RubyLLM.config),
        chats: [], id: 'msgbatch_123', raw_status: 'in_progress', completed: false
      )

      expect(batch.inspect).to include('msgbatch_123', 'pending', 'in_progress')
    end
  end

  describe '#cost' do
    it 'is empty for a batch that collected nothing' do
      batch = described_class.new(
        provider: RubyLLM::Providers::Anthropic.new(RubyLLM.config),
        chats: [], id: 'msgbatch_123', raw_status: 'ended', completed: true
      )
      allow(batch).to receive(:messages).and_return([nil])

      expect(batch.cost.total).to be_nil
    end
  end
end
