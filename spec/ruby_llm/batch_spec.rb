# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Batch, :live do
  let(:model) { 'claude-haiku-4-5' }

  def wait_for(batch)
    40.times do
      break if batch.refresh.complete?

      sleep 15 if VCR.current_cassette.recording?
    end
    batch
  end

  describe '.submit' do
    it 'rejects an empty batch' do
      expect { RubyLLM.batch([]) }.to raise_error(ArgumentError, /empty batch/)
    end

    it 'rejects chats that are not awaiting the model' do
      expect { RubyLLM.batch([RubyLLM.chat(model: model)]) }
        .to raise_error(ArgumentError, /awaiting the model/)
    end

    it 'rejects mixed providers' do
      chats = [
        RubyLLM.chat(model: model).ask_later('Hi'),
        RubyLLM.chat(model: 'gpt-5-nano').ask_later('Hi')
      ]

      expect { RubyLLM.batch(chats) }.to raise_error(ArgumentError, /one provider/)
    end

    it 'rejects mixing chats with embedding requests' do
      items = [
        RubyLLM.chat(model: 'gpt-5-nano').ask_later('Hi'),
        RubyLLM.embed_later('Hi', model: 'text-embedding-3-small')
      ]

      expect { RubyLLM.batch(items) }.to raise_error(ArgumentError, /chats or embedding requests/)
    end

    it 'rejects mixed models for model-scoped providers' do
      chats = [
        RubyLLM.chat(model: 'gpt-5-nano').ask_later('Hi'),
        RubyLLM.chat(model: 'gpt-5-mini').ask_later('Hi')
      ]

      expect { RubyLLM.batch(chats) }.to raise_error(RubyLLM::Error, /one model/)
    end

    it 'rejects providers without batch support' do
      chats = [RubyLLM.chat(model: 'deepseek-chat', provider: :deepseek, assume_model_exists: true).ask_later('Hi')]

      expect { RubyLLM.batch(chats) }.to raise_error(RubyLLM::Error, /batch/)
    end

    it 'routes Vertex AI batches by protocol' do
      provider = RubyLLM::Provider.resolve!(:vertexai).new(RubyLLM.config)

      expect(provider.batches?).to be(true)
      expect(provider.send(:batch_protocol_for, [{ model: 'gemini-2.5-flash', payload: {} }]))
        .to be < RubyLLM::Providers::VertexAI::Gemini
      expect(provider.send(:batch_protocol_for, [{ model: 'claude-haiku-4-5', payload: {} }]))
        .to be < RubyLLM::Providers::VertexAI::Anthropic
      expect(provider.send(:batch_protocol_for, [{ model: 'meta/llama-3.3-70b-instruct-maas', payload: {} }]))
        .to be < RubyLLM::Providers::VertexAI::ChatCompletions
      expect { provider.send(:batch_protocol_for, [{ model: 'mistral-small-2503', payload: {} }]) }
        .to raise_error(RubyLLM::Error, /Gemini, Anthropic, and MaaS/)
    end

    it 'passes rendered payloads and model ids to provider batch implementations' do
      chat = RubyLLM.chat(model: 'mistral-small-latest').ask_later('Hi')
      allow(chat.provider).to receive(:create_batch) do |requests|
        expect(requests.first).to include(
          custom_id: '0',
          model: 'mistral-small-latest',
          payload: include(:model, :messages)
        )
        { id: 'batch_test', raw_status: 'RUNNING', completed: false }
      end

      RubyLLM.batch(chat)

      expect(chat.provider).to have_received(:create_batch)
    end
  end

  describe '.submit with a single chat' do
    it 'wraps it without decomposing the conversation' do
      chat = RubyLLM.chat(model: model).ask_later('Hi')
      allow(chat.provider).to receive(:create_batch)
        .and_return(id: 'msgbatch_test', raw_status: 'in_progress', completed: false)

      batch = RubyLLM.batch(chat)

      expect(batch.chats).to eq([chat])
    end
  end

  describe '.find' do
    it 'requires a provider' do
      expect { described_class.find('msgbatch_123', provider: nil) }.to raise_error(ArgumentError, /Provider/)
    end
  end

  describe '#messages' do
    it 'leaves failed slots nil and their chats awaiting a response' do
      chats = [
        RubyLLM.chat(model: model).ask_later('This one fails'),
        RubyLLM.chat(model: model).ask_later('This one succeeds')
      ]
      provider = chats.first.provider
      message = RubyLLM::Message.new(role: :assistant, content: '4', input_tokens: 1, output_tokens: 1)
      allow(provider).to receive(:batch_results).and_return([[0, nil, :failed], [1, message]])

      batch = described_class.new(provider:, chats:, id: 'msgbatch_test', raw_status: 'ended', completed: true)

      expect(batch.messages).to eq([nil, message])
      expect(batch.statuses).to eq(%i[failed succeeded])
      expect(batch.tokens.to_h).to eq(input_tokens: 1, output_tokens: 1)
      expect(batch.cost).to be_a(RubyLLM::Cost)
      expect(chats.first).not_to be_complete
      expect(chats.second.messages.last).to be(message)

      batch.messages
      expect(provider).to have_received(:batch_results).once
    end

    it 'records successful responses at batch prices' do
      instrumenter = CaptureInstrumenter.new
      context = RubyLLM.context { |config| config.instrumenter = instrumenter }
      chat = context.chat(model: model).ask_later('Hi')
      provider = chat.provider
      batch_pricing = {
        text_tokens: {
          standard: { input_per_million: 1, output_per_million: 5 },
          batch: { input_per_million: 0.5, output_per_million: 2.5 }
        }
      }
      chat.instance_variable_set(:@model, RubyLLM::Model.new(chat.model.to_h.merge(pricing: batch_pricing)))
      message = RubyLLM::Message.new(role: :assistant, content: 'Hello', input_tokens: 1_000, output_tokens: 2_000)
      allow(provider).to receive(:batch_results).and_return([[0, message]])

      batch = described_class.new(provider:, chats: [chat], id: 'msgbatch_test', raw_status: 'ended', completed: true)

      batch.messages

      expect(instrumenter.events.sole).to match(
        ['usage.ruby_llm', include(
          operation: :chat,
          provider: 'anthropic',
          model: model,
          status: :succeeded,
          cost: satisfy { |cost| cost.total.then { |total| (total - 0.0055).abs < 1e-12 } }
        )]
      )
      expect(message.cost.total).to eq(0.0055)
      expect(chat.cost.total).to eq(0.0055)
      expect(chat.usage_entries).to eq(message.ruby_llm_usage_entries)
    end

    it 'applies the provider batch discount when the model has no batch tier' do
      chat = RubyLLM.chat(model: model).ask_later('Hi')
      provider = chat.provider
      message = RubyLLM::Message.new(role: :assistant, content: 'Hello', input_tokens: 1_000, output_tokens: 2_000)
      allow(provider).to receive(:batch_results).and_return([[0, message]])
      standard_cost = chat.model.cost_for(message.tokens).total

      batch = described_class.new(provider:, chats: [chat], id: 'msgbatch_test', raw_status: 'ended', completed: true)
      batch.messages

      expect(message.cost.total).to be_within(1e-12).of(standard_cost * 0.5)
    end

    it 'does not instrument an already-delivered response twice' do
      instrumenter = CaptureInstrumenter.new
      context = RubyLLM.context { |config| config.instrumenter = instrumenter }
      chat = context.chat(model: model).ask_later('Hi')
      provider = chat.provider
      first = RubyLLM::Message.new(role: :assistant, content: 'Hello', model:, input_tokens: 1, output_tokens: 1)
      second = RubyLLM::Message.new(role: :assistant, content: 'Hello', model:, input_tokens: 1, output_tokens: 1)
      allow(provider).to receive(:batch_results).and_return([[0, first]], [[0, second]])

      collect = lambda do
        described_class.new(
          provider:, chats: [chat], id: 'msgbatch_test', raw_status: 'ended', completed: true
        ).messages
      end

      collect.call
      collect.call

      expect(instrumenter.events.count { |name, _payload| name == 'usage.ruby_llm' }).to eq(1)
      expect(second.ruby_llm_usage_entries).not_to be_empty
    end

    it 'does not re-deliver a tool-call answer after its tools have run' do
      chat = RubyLLM.chat(model: model).ask_later('Look it up.')
      provider = chat.provider
      answer = RubyLLM::Message.new(
        role: :assistant, content: nil, input_tokens: 1, output_tokens: 1,
        tool_calls: { 'toolu_1' => RubyLLM::ToolCall.new(id: 'toolu_1', name: 'lookup', arguments: {}) }
      )
      allow(provider).to receive(:batch_results).and_return([[0, answer]])

      collect = lambda do
        described_class.new(
          provider:, chats: [chat], id: 'msgbatch_test', raw_status: 'ended', completed: true
        ).messages
      end

      collect.call # first delivery appends the tool-call answer
      # the app runs the tool, appending a result and moving the chat on
      chat.add_message(RubyLLM::Message.new(role: :tool, content: 'done', tool_call_id: 'toolu_1'))
      collect.call # a redelivered poll re-collects the same batch

      expect(chat.messages.count(&:tool_call?)).to eq(1)
    end
  end

  describe '#results' do
    it 'hydrates embeddings into their staged requests and leaves failed slots nil' do
      requests = [
        RubyLLM.embed_later('This one fails', model: 'text-embedding-3-small'),
        RubyLLM.embed_later('This one succeeds', model: 'text-embedding-3-small')
      ]
      provider = requests.first.provider
      embedding = RubyLLM::Embedding.new(vectors: [0.1, 0.2], model: 'text-embedding-3-small', input_tokens: 3)
      standard_cost = embedding.cost.total
      allow(provider).to receive(:batch_results).and_return([[0, nil, :failed], [1, embedding]])

      batch = described_class.new(provider:, requests:, id: 'batch_test', raw_status: 'completed', completed: true)

      expect(batch.results).to eq([nil, embedding])
      expect(batch.statuses).to eq(%i[failed succeeded])
      expect(requests.first.result).to be_nil
      expect(requests.second.result).to be(embedding)
      expect(batch.tokens.input).to eq(3)
      expect(embedding.ruby_llm_usage_entries.sole.operation).to eq(:embedding)
      expect(embedding.cost.total).to be_within(1e-12).of(standard_cost * 0.5)
      expect(batch.cost.total).to eq(embedding.cost.total)
    end
  end

  # Not covered live: Azure batches need a Global-Batch deployment on the test
  # resource, and Bedrock/Vertex AI batches need real S3/GCS buckets and roles.
  [
    { provider: :gemini, model: 'gemini-2.5-flash' },
    { provider: :mistral, model: 'mistral-small-latest' },
    { provider: :openai, model: 'gpt-5-nano' },
    { provider: :xai, model: 'grok-4-1-fast-non-reasoning' }
  ].each do |model_info|
    context "with #{model_info[:provider]}/#{model_info[:model]}" do
      it 'answers staged chats and appends the answers to their conversations' do
        chats = [
          RubyLLM.chat(model: model_info[:model], provider: model_info[:provider])
                 .ask_later('What is 2 + 2? Just the number.'),
          RubyLLM.chat(model: model_info[:model], provider: model_info[:provider])
                 .ask_later('Name the largest planet in our solar system. One word.')
        ]

        batch = RubyLLM.batch(chats)

        expect(batch.id).to be_present

        wait_for batch

        expect(batch).to be_complete
        expect(batch.messages.first.content).to include('4')
        expect(batch.messages.second.content).to match(/jupiter/i)
        expect(chats.second.messages.map(&:role)).to eq(%i[user assistant])
      end
    end
  end

  context 'with openai/text-embedding-3-small embeddings' do
    it 'embeds staged texts and hydrates each request result' do
      requests = [
        RubyLLM.embed_later('Ruby is a programmer best friend', model: 'text-embedding-3-small'),
        RubyLLM.embed_later('Batches come back within a day', model: 'text-embedding-3-small', dimensions: 256)
      ]

      batch = RubyLLM.batch(requests)

      expect(batch.id).to be_present

      wait_for batch

      expect(batch).to be_complete
      expect(batch.results.first.vectors.length).to eq(1536)
      expect(batch.results.second.vectors.length).to eq(256)
      expect(requests.first.result).to be(batch.results.first)
      expect(requests.first.result.tokens.input).to be_positive
    end
  end

  context 'with anthropic/claude-haiku-4-5' do
    it 'answers staged chats and appends the answers to their conversations' do
      chats = [
        RubyLLM.chat(model: model).with_instructions('Be terse.').ask_later('What is 2 + 2?'),
        RubyLLM.chat(model: model).ask_later('Name the largest planet in our solar system. One word.')
      ]

      batch = RubyLLM.batch(chats)

      expect(batch.id).to start_with('msgbatch_')
      expect(batch.status).to eq(:pending)
      expect(batch.raw_status).to eq('in_progress')

      wait_for batch

      expect(batch).to be_complete
      expect(batch.messages.first.content).to include('4')
      expect(batch.messages.second.content).to match(/jupiter/i)
      expect(batch.messages.first.tokens.input).to be_positive
      expect(chats.first.messages.map(&:role)).to eq(%i[system user assistant])
    end

    it 'reloads a batch by id and collects messages without the chats' do
      submitted = RubyLLM.batch([RubyLLM.chat(model: model).ask_later('What is 3 + 3? Just the number.')])
      wait_for submitted

      batch = described_class.find(submitted.id, provider: :anthropic)

      expect(batch).to be_complete
      expect(batch.messages.first.content).to include('6')
    end

    it 'cancels a running batch' do
      batch = RubyLLM.batch([RubyLLM.chat(model: model).ask_later('What is 5 + 5?')])

      batch.cancel

      expect(batch.status).to be_in(%i[pending succeeded])
      expect(batch.raw_status).to be_in(%w[canceling ended])
    end
  end
end
