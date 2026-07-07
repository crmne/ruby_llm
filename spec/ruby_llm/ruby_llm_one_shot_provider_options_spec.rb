# frozen_string_literal: true

require 'spec_helper'

class OneShotCaptureInstrumenter
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

RSpec.describe RubyLLM do
  let(:instrumenter) { OneShotCaptureInstrumenter.new }
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

  it 'forwards embedding provider options and includes metadata in the event payload' do
    embedding = RubyLLM::Embedding.new(vectors: [0.1, 0.2], model: 'test-model', input_tokens: 3)
    allow(provider).to receive(:embed).and_return(embedding)

    result = api_context.embed('hello', model: 'test-model', provider_options: provider_options, metadata: metadata)

    expect(result).to eq(embedding)
    expect(provider).to have_received(:embed)
      .with('hello', model: model, dimensions: nil, task_type: nil, title: nil, provider_options: provider_options)
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
    expect(provider).to have_received(:moderate).with('check this', model: model, provider_options: provider_options)
    _event_name, payload = instrumenter.events.last
    expect(payload[:provider_options]).to eq(provider_options)
    expect(payload[:metadata]).to eq(metadata)
  end

  it 'forwards speech provider options and includes metadata in the event payload' do
    speech = RubyLLM::Speech.new(data: 'audio bytes', model: 'test-model')
    allow(provider).to receive(:speak).and_return(speech)

    result = api_context.speak('say this', model: 'test-model', provider_options: provider_options, metadata: metadata)

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

  def api_context
    described_class.context { |config| config.instrumenter = instrumenter }
  end
end
