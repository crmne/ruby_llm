# frozen_string_literal: true

require 'spec_helper'

class CaptureInstrumenter
  attr_reader :events

  def initialize
    @events = []
  end

  def instrument(name, payload)
    result = block_given? ? yield : nil
    events << [name, payload.dup]
    result
  end
end

RSpec.describe RubyLLM::Instrumentation do
  include_context 'with configured RubyLLM'

  it 'emits structured events through a Rails-compatible instrumenter' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }

    result = described_class.instrument('example.ruby_llm', provider: 'openai', config: context.config) { :ok }

    expect(result).to eq(:ok)

    expect(instrumenter.events).to eq([['example.ruby_llm', { provider: 'openai' }]])
  end

  it 'allows no-op events when no instrumenter is configured' do
    context = RubyLLM.context { |config| config.instrumenter = nil }

    expect(described_class.instrument('example.ruby_llm', config: context.config)).to be_nil
  end

  it 'falls back to the block when the instrumenter is invalid' do
    context = RubyLLM.context { |config| config.instrumenter = Object.new }

    expect(described_class.instrument('example.ruby_llm', config: context.config) { :ok }).to eq(:ok)
  end

  it 'does not swallow errors from the instrumented block' do
    instrumenter = Class.new do
      def instrument(_name, _payload)
        yield
      end
    end.new

    context = RubyLLM.context { |config| config.instrumenter = instrumenter }

    expect do
      described_class.instrument('example.ruby_llm', config: context.config) { nil.missing_method }
    end.to raise_error(NoMethodError)
  end

  it 'emits rich chat events around the whole completion flow' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    chat = context.chat(model: 'gpt-4.1-nano')
    chat.with_temperature(0.2)
    provider = chat.instance_variable_get(:@provider)
    response = RubyLLM::Message.new(
      role: :assistant,
      content: 'done',
      model_id: 'gpt-4.1-nano',
      input_tokens: 10,
      output_tokens: 5,
      cached_tokens: 2,
      thinking_tokens: 1
    )
    allow(provider).to receive(:complete).and_return(response)

    chat.ask('Hello')

    event_name, payload = instrumenter.events.last
    expect(event_name).to eq('chat.ruby_llm')
    expect(payload).to include(
      provider: 'openai',
      model: 'gpt-4.1-nano',
      response: response,
      response_model: 'gpt-4.1-nano',
      input_tokens: 10,
      output_tokens: 5,
      cached_tokens: 2,
      thinking_tokens: 1,
      temperature: 0.2,
      streaming: false,
      metadata: nil
    )
    expect(payload).not_to have_key(:operation)
    expect(payload).not_to have_key(:result)
    expect(payload[:input_messages].first.content).to eq('Hello')
    expect(payload[:messages_after].last.content).to eq('done')
  end

  it 'includes with_metadata in chat and tool_call instrumentation payloads' do
    stub_const('MetadataProbeTool', Class.new(RubyLLM::Tool) do
      param :value

      def execute(value:)
        "tool #{value}"
      end
    end)
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'metadata_probe', arguments: { value: 'ok' })
    tool_message = RubyLLM::Message.new(role: :assistant, content: nil, tool_calls: { 'call_1' => tool_call })
    final_message = RubyLLM::Message.new(role: :assistant, content: 'complete')
    chat = context.chat(model: 'gpt-4.1-nano')
                   .with_metadata(namespace: :summary, tags: { type: 'doc' })
                   .with_metadata(tags: { academy_id: 42 })
                   .with_tool(MetadataProbeTool)
    provider = chat.instance_variable_get(:@provider)
    allow(provider).to receive(:complete).and_return(tool_message, final_message)

    chat.ask('Use the tool')

    expect(chat.metadata.namespace).to eq(:summary)
    expect(chat.metadata.tags).to eq(type: 'doc', academy_id: 42)

    chat_payload = instrumenter.events.find { |name, _| name == 'chat.ruby_llm' }.last
    expect(chat_payload[:metadata]).to eq(chat.metadata)
    expect(chat_payload[:metadata].namespace).to eq(:summary)
    expect(chat_payload[:metadata].tags).to include(type: 'doc', academy_id: 42)

    tool_payload = instrumenter.events.find { |name, _| name == 'tool_call.ruby_llm' }.last
    expect(tool_payload[:metadata]).to eq(chat.metadata)
  end

  it 'marks streaming chat events when a block is passed' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    chat = context.chat(model: 'gpt-4.1-nano')
    provider = chat.instance_variable_get(:@provider)
    response = RubyLLM::Message.new(role: :assistant, content: 'done', model_id: 'gpt-4.1-nano')
    allow(provider).to receive(:complete).and_return(response)

    chat.ask('Hello') { |chunk| chunk }

    _event_name, payload = instrumenter.events.last
    expect(payload[:streaming]).to be(true)
  end

  it 'emits tool call events with arguments and result' do
    stub_const('InstrumentationProbeTool', Class.new(RubyLLM::Tool) do
      param :value

      def execute(value:)
        "tool #{value}"
      end
    end)
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'instrumentation_probe', arguments: { value: 'ok' })
    tool_message = RubyLLM::Message.new(role: :assistant, content: nil, tool_calls: { 'call_1' => tool_call })
    final_message = RubyLLM::Message.new(role: :assistant, content: 'complete')
    chat = context.chat(model: 'gpt-4.1-nano').with_tool(InstrumentationProbeTool)
    provider = chat.instance_variable_get(:@provider)
    allow(provider).to receive(:complete).and_return(tool_message, final_message)

    chat.ask('Use the tool')

    _event_name, payload = instrumenter.events.find { |name, _payload| name == 'tool_call.ruby_llm' }
    expect(payload).to include(
      provider: 'openai',
      model: 'gpt-4.1-nano',
      tool_name: 'instrumentation_probe',
      tool_call_id: 'call_1',
      tool_arguments: { value: 'ok' },
      result: 'tool ok',
      result_content: 'tool ok',
      result_class: 'String'
    )
    expect(payload[:tool]).to be_a(InstrumentationProbeTool)
    expect(payload).not_to have_key(:operation)
    expect(payload).not_to have_key(:tool_object)
  end

  it 'emits embedding events with usage and vector dimensions' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    model = instance_double(RubyLLM::Model::Info, id: 'text-embedding-3-small', provider: 'openai')
    provider = instance_double(RubyLLM::Provider, slug: 'openai')
    provider_class = class_double(RubyLLM::Provider, display_name: 'OpenAI')
    embedding = RubyLLM::Embedding.new(vectors: [[0.1, 0.2, 0.3]], model: 'text-embedding-3-small', input_tokens: 8)
    allow(provider).to receive_messages(embed: embedding, class: provider_class)
    allow(RubyLLM::Models).to receive(:resolve).and_return([model, provider])

    result = context.embed(['hello'], model: 'text-embedding-3-small',
                                      metadata: { namespace: :search, tags: { index: 'docs' } })

    event_name, payload = instrumenter.events.last
    expect(result).to eq(embedding)
    expect(event_name).to eq('embedding.ruby_llm')
    expect(payload).to include(
      provider: 'openai',
      provider_class: 'OpenAI',
      model: 'text-embedding-3-small',
      input: ['hello'],
      result: embedding,
      response_model: 'text-embedding-3-small',
      input_tokens: 8,
      embedding_dimensions: 3,
      embedding_count: 1
    )
    expect(payload[:metadata]).to be_a(RubyLLM::Metadata)
    expect(payload[:metadata].namespace).to eq(:search)
    expect(payload[:metadata].tags).to eq(index: 'docs')
    expect(payload).not_to have_key(:operation)
  end

  it 'emits speech events with output metadata' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    model = instance_double(RubyLLM::Model::Info, id: 'gpt-4o-mini-tts', provider: 'openai')
    provider = instance_double(RubyLLM::Provider, slug: 'openai')
    provider_class = class_double(RubyLLM::Provider, display_name: 'OpenAI')
    speech = RubyLLM::Speech.new(data: 'audio bytes', model: 'gpt-4o-mini-tts', voice: 'alloy', format: 'mp3')
    allow(provider).to receive_messages(speak: speech, class: provider_class)
    allow(RubyLLM::Models).to receive(:resolve).and_return([model, provider])

    result = context.speak('hello', model: 'gpt-4o-mini-tts')

    event_name, payload = instrumenter.events.last
    expect(result).to eq(speech)
    expect(event_name).to eq('speech.ruby_llm')
    expect(payload).to include(
      provider: 'openai',
      provider_class: 'OpenAI',
      model: 'gpt-4o-mini-tts',
      input: 'hello',
      result: speech,
      response_model: 'gpt-4o-mini-tts',
      voice: 'alloy',
      format: 'mp3',
      audio_bytes: 11
    )
    expect(payload).not_to have_key(:operation)
  end
end
