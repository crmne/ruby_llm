# frozen_string_literal: true

require 'spec_helper'

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
      model: 'gpt-4.1-nano',
      input_tokens: 10,
      output_tokens: 5,
      cache_read_tokens: 2,
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
      tokens: response.tokens,
      temperature: 0.2,
      streaming: false
    )
    expect(payload).not_to have_key(:operation)
    expect(payload[:cost].total).to eq(response.cost.total)
    expect(payload).not_to have_key(:result)
    expect(payload[:input_messages].first.content).to eq('Hello')
    expect(payload[:messages_after].last.content).to eq('done')

    _usage_name, usage = instrumenter.events.find { |name, _event| name == 'usage.ruby_llm' }
    expect(usage).to include(status: :succeeded, tokens: response.tokens)
    expect(usage[:cost].total).to eq(response.cost.total)
  end

  it 'marks streaming chat events when a block is passed' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    chat = context.chat(model: 'gpt-4.1-nano')
    provider = chat.instance_variable_get(:@provider)
    response = RubyLLM::Message.new(role: :assistant, content: 'done', model: 'gpt-4.1-nano')
    allow(provider).to receive(:complete).and_return(response)

    chat.ask('Hello') { |chunk| chunk }

    _event_name, payload = instrumenter.events.last
    expect(payload[:streaming]).to be(true)
  end

  it 'emits one usage event for every transport attempt' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context do |config|
      config.instrumenter = instrumenter
      config.max_retries = 1
    end
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(
        {
          status: 500,
          headers: { 'Content-Type' => 'application/json' },
          body: { error: { message: 'try again' } }.to_json
        },
        {
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: {
            model: 'gpt-4.1-nano',
            choices: [{ message: { role: 'assistant', content: 'done' }, finish_reason: 'stop' }],
            usage: { prompt_tokens: 5, completion_tokens: 2 }
          }.to_json
        }
      )

    context.chat(model: 'gpt-4.1-nano', provider: :openai, protocol: :chat_completions).ask('Hello')

    events = instrumenter.events.select { |event| event.first == 'usage.ruby_llm' }
    expect(events.map { |_name, payload| payload[:status] }).to eq(%i[failed succeeded])
    expect(events.last.last).to include(
      operation: :chat,
      provider: 'openai',
      model: 'gpt-4.1-nano',
      status: :succeeded
    )
    expect(events.last.last[:tokens].to_h).to eq(input_tokens: 5, output_tokens: 2, cache_write_tokens: 0)
    expect(events.last.last[:cost].total).to be_a(Numeric)
    expect(events.last.last).not_to have_key(:usage_status)
    expect(events.last.last).not_to have_key(:usage)
  end

  it 'emits tool call events with arguments and result' do
    stub_const('InstrumentationProbeTool', Class.new(RubyLLM::Tool) do
      parameter :value

      def execute(value:)
        "tool #{value}"
      end
    end)
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'instrumentation_probe', arguments: { value: 'ok' })
    tool_message = RubyLLM::Message.new(role: :assistant, content: nil, tool_calls: { 'call_1' => tool_call })
    final_message = RubyLLM::Message.new(role: :assistant, content: 'complete')
    chat = context.chat(model: 'gpt-4.1-nano').with_tools(InstrumentationProbeTool)
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
    model = instance_double(RubyLLM::Model, id: 'text-embedding-3-small', provider: 'openai')
    provider = instance_double(RubyLLM::Provider, slug: 'openai')
    provider_class = class_double(RubyLLM::Provider, display_name: 'OpenAI')
    embedding = RubyLLM::Embedding.new(vectors: [[0.1, 0.2, 0.3]], model: 'text-embedding-3-small', input_tokens: 8)
    allow(provider).to receive_messages(embed: embedding, class: provider_class)
    allow(RubyLLM::Models).to receive(:resolve).and_return([model, provider])

    result = context.embed(['hello'], model: 'text-embedding-3-small')

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
      embedding_dimensions: 3,
      embedding_count: 1
    )
    expect(payload[:tokens].to_h).to eq(input_tokens: 8)
    expect(payload[:cost]).to be_a(RubyLLM::Cost)
    expect(payload).not_to have_key(:operation)
  end

  it 'emits speech events with output metadata' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    model = instance_double(RubyLLM::Model, id: 'gpt-4o-mini-tts', provider: 'openai')
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
    expect(payload[:tokens]).to be_a(RubyLLM::Tokens)
    expect(payload[:cost]).to be_a(RubyLLM::Cost)
    expect(payload).not_to have_key(:operation)
  end

  describe 'one-shot provider options' do
    let(:instrumenter) { CaptureInstrumenter.new }
    let(:model) { instance_double(RubyLLM::Model, id: 'test-model', provider: 'openai') }
    let(:provider) do
      provider_class = class_double(RubyLLM::Provider, display_name: 'OpenAI')
      instance_double(RubyLLM::Provider, slug: 'openai', class: provider_class)
    end
    let(:provider_options) { { custom: 'value' } }
    let(:metadata) { { academy_id: 42, feature: 'search' } }

    before do
      allow(RubyLLM::Models).to receive(:resolve).and_return([model, provider])
    end

    def api_context
      RubyLLM.context { |config| config.instrumenter = instrumenter }
    end

    it 'forwards embedding provider options and includes metadata in the event payload' do
      embedding = RubyLLM::Embedding.new(vectors: [0.1, 0.2], model: 'test-model', input_tokens: 3)
      allow(provider).to receive(:embed).and_return(embedding)

      result = api_context.embed('hello', model: 'test-model', provider_options: provider_options, metadata: metadata)

      expect(result).to eq(embedding)
      expect(provider).to have_received(:embed)
        .with('hello', model: model, dimensions: nil, task_type: nil, title: nil, with: nil,
                       provider_options: provider_options)
      _event_name, payload = instrumenter.events.last
      expect(payload[:provider_options]).to eq(provider_options)
      expect(payload[:metadata]).to eq(metadata)
    end

    it 'forwards image provider options and includes metadata in the event payload' do
      image = RubyLLM::Image.new(model: 'test-model')
      allow(provider).to receive(:paint).and_return(image)

      result = api_context.paint('draw this', model: 'test-model', provider_options: provider_options,
                                              metadata: metadata)

      expect(result).to eq(image)
      expect(provider).to have_received(:paint).with(
        'draw this',
        model: model,
        size: '1024x1024',
        with: nil,
        mask: nil,
        provider_options: provider_options
      )
      _event_name, payload = instrumenter.events.last
      expect(payload[:provider_options]).to eq(provider_options)
      expect(payload[:metadata]).to eq(metadata)
    end

    it 'forwards moderation provider options and includes metadata in the event payload' do
      moderation = RubyLLM::Moderation.new(id: 'mod_123', model: 'test-model', results: [])
      allow(provider).to receive(:moderate).and_return(moderation)

      result = api_context.moderate('check this', model: 'test-model', provider_options: provider_options,
                                                  metadata: metadata)

      expect(result).to eq(moderation)
      expect(provider).to have_received(:moderate).with('check this', model: model, with: [],
                                                                      provider_options: provider_options)
      _event_name, payload = instrumenter.events.last
      expect(payload[:provider_options]).to eq(provider_options)
      expect(payload[:metadata]).to eq(metadata)
    end

    it 'forwards moderation attachments' do
      moderation = RubyLLM::Moderation.new(id: 'mod_123', model: 'test-model', results: [])
      allow(provider).to receive(:moderate).and_return(moderation)

      result = api_context.moderate('check this',
                                    with: ['https://example.com/safe.png', 'https://example.com/also-safe.png'],
                                    model: 'test-model')

      expect(result).to eq(moderation)
      expect(provider).to have_received(:moderate).with(
        'check this',
        model: model,
        with: [an_instance_of(RubyLLM::Attachment), an_instance_of(RubyLLM::Attachment)],
        provider_options: {}
      )
      _event_name, payload = instrumenter.events.last
      expect(payload[:attachment_count]).to eq(2)
    end

    it 'forwards speech provider options and includes metadata in the event payload' do
      speech = RubyLLM::Speech.new(data: 'audio bytes', model: 'test-model')
      allow(provider).to receive(:speak).and_return(speech)

      result = api_context.speak('say this', model: 'test-model', provider_options: provider_options,
                                             metadata: metadata)

      expect(result).to eq(speech)
      expect(provider).to have_received(:speak).with(
        'say this',
        model: model,
        voice: nil,
        format: nil,
        provider_options: provider_options
      )
      _event_name, payload = instrumenter.events.last
      expect(payload[:provider_options]).to eq(provider_options)
      expect(payload[:metadata]).to eq(metadata)
    end

    it 'forwards transcription provider options and includes metadata in the event payload' do
      transcription = RubyLLM::Transcription.new(text: 'hello', model: 'test-model')
      allow(provider).to receive(:transcribe).and_return(transcription)

      result = api_context.transcribe('audio.wav', model: 'test-model', provider_options: provider_options,
                                                   metadata: metadata)

      expect(result).to eq(transcription)
      expect(provider).to have_received(:transcribe).with('audio.wav', model: model, language: nil,
                                                                       format: nil, speaker_names: nil,
                                                                       speaker_references: nil,
                                                                       provider_options: provider_options,
                                                                       prompt: nil, temperature: nil)
      _event_name, payload = instrumenter.events.last
      expect(payload[:provider_options]).to eq(provider_options)
      expect(payload[:metadata]).to eq(metadata)
    end
  end
end
