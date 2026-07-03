# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  class FallbackSpecProvider # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    attr_reader :slug, :connection

    def self.display_name
      'Fallback Spec Provider'
    end

    def initialize(slug)
      @slug = slug
      @connection = Object.new
    end

    def preprocess_message(message, **)
      message
    end
  end

  before do
    allow(RubyLLM::Models).to receive(:resolve).and_call_original
    allow(RubyLLM::Provider).to receive(:resolve!).and_call_original
    stub_model_resolution('primary-model', nil, primary_model, primary_provider)
    stub_model_resolution('fallback-model', nil, fallback_model, fallback_provider)
    stub_model_resolution('fallback-model', :anthropic, fallback_model, fallback_provider)
    stub_model_resolution('second-fallback-model', nil, second_fallback_model, second_fallback_provider)
    stub_provider_resolution('anthropic', fallback_provider)
    stub_provider_resolution('openrouter', second_fallback_provider)
  end

  def model_info(id, provider)
    RubyLLM::Model.new(id: id, name: id, provider: provider)
  end

  def primary_provider
    @primary_provider ||= FallbackSpecProvider.new(:openai)
  end

  def fallback_provider
    @fallback_provider ||= FallbackSpecProvider.new(:anthropic)
  end

  def second_fallback_provider
    @second_fallback_provider ||= FallbackSpecProvider.new(:openrouter)
  end

  def primary_model
    @primary_model ||= model_info('primary-model', 'openai')
  end

  def fallback_model
    @fallback_model ||= model_info('fallback-model', 'anthropic')
  end

  def second_fallback_model
    @second_fallback_model ||= model_info('second-fallback-model', 'openrouter')
  end

  def stub_model_resolution(id, provider, model, provider_instance)
    allow(RubyLLM::Models).to receive(:resolve)
      .with(id, provider: provider, assume_exists: false, config: anything)
      .and_return([model, provider_instance])
  end

  def stub_provider_resolution(provider, provider_instance)
    provider_class = Class.new
    allow(provider_class).to receive(:new).and_return(provider_instance)
    allow(RubyLLM::Provider).to receive(:resolve!).with(provider).and_return(provider_class)
  end

  it 'stores ordered fallback models' do
    chat = described_class.new(model: 'primary-model')

    chat.with_fallbacks('fallback-model', second_fallback_model)

    expect(chat.fallbacks.map(&:id)).to eq(%w[fallback-model second-fallback-model])
    expect(chat.fallbacks.last.provider).to eq(:openrouter)
    expect(chat.fallback_errors).to eq(RubyLLM::Fallback::DEFAULT_ERRORS)
  end

  it 'falls back on transient errors and restores the primary model' do
    chat = described_class.new(model: 'primary-model').with_fallbacks('fallback-model')
    allow(primary_provider).to receive(:complete)
      .and_raise(RubyLLM::ServiceUnavailableError.new(nil, 'primary down'))
    allow(fallback_provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'from fallback', model_id: 'fallback-model'))

    chat.ask_later('Hello')
    response = chat.generate

    expect(response.content).to eq('from fallback')
    expect(chat.model).to eq(primary_model)
    expect(chat.provider).to eq(primary_provider)
    expect(chat.messages.last.model_id).to eq('fallback-model')
  end

  it 'tries fallback models in order' do
    chat = described_class.new(model: 'primary-model').with_fallbacks('fallback-model', 'second-fallback-model')
    allow(primary_provider).to receive(:complete)
      .and_raise(RubyLLM::RateLimitError.new(nil, 'primary rate limited'))
    allow(fallback_provider).to receive(:complete)
      .and_raise(RubyLLM::OverloadedError.new(nil, 'fallback overloaded'))
    allow(second_fallback_provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'second fallback'))

    chat.ask_later('Hello')
    response = chat.generate

    expect(response.content).to eq('second fallback')
    expect(primary_provider).to have_received(:complete).once
    expect(fallback_provider).to have_received(:complete).once
    expect(second_fallback_provider).to have_received(:complete).once
  end

  it 'does not fallback on non-transient errors' do
    chat = described_class.new(model: 'primary-model').with_fallbacks('fallback-model')
    allow(primary_provider).to receive(:complete)
      .and_raise(RubyLLM::BadRequestError.new(nil, 'bad request'))
    allow(fallback_provider).to receive(:complete)

    chat.ask_later('Hello')

    expect { chat.generate }.to raise_error(RubyLLM::BadRequestError)
    expect(fallback_provider).not_to have_received(:complete)
  end

  it 'falls back on configured errors' do
    chat = described_class.new(model: 'primary-model')
                          .with_fallbacks('fallback-model', on: RubyLLM::BadRequestError)
    allow(primary_provider).to receive(:complete)
      .and_raise(RubyLLM::BadRequestError.new(nil, 'bad request'))
    allow(fallback_provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'ok'))

    chat.ask_later('Hello')
    response = chat.generate

    expect(response.content).to eq('ok')
    expect(chat.fallback_errors).to eq([RubyLLM::BadRequestError])
  end

  it 'runs fallback callbacks before retrying' do
    chat = described_class.new(model: 'primary-model')
                          .with_fallbacks(fallback_model)
    allow(primary_provider).to receive(:complete)
      .and_raise(RubyLLM::ServerError.new(nil, 'primary failed'))
    allow(fallback_provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'ok'))
    before_events = []
    after_events = []
    chat.before_fallback { |event| before_events << event }
        .after_fallback { |event| after_events << event }

    chat.ask_later('Hello')
    chat.generate

    expect(before_events.size).to eq(1)
    expect(before_events.first).to be_a(RubyLLM::Fallback)
    expect(before_events.first.error).to be_a(RubyLLM::ServerError)
    expect(before_events.first.from.id).to eq('primary-model')
    expect(before_events.first.to.id).to eq('fallback-model')
    expect(before_events.first.to.provider).to eq('anthropic')
    expect(before_events.first.attempt).to eq(1)
    expect(before_events.first).not_to be_streaming
    expect(before_events.first).not_to be_chunks_yielded

    expect(after_events.size).to eq(1)
    expect(after_events.first.response.content).to eq('ok')
    expect(after_events.first).to be_succeeded
    expect(after_events.first).not_to be_failed
  end

  it 'starts a new streaming message lifecycle when fallback follows yielded chunks' do
    chat = described_class.new(model: 'primary-model').with_fallbacks('fallback-model')
    allow(primary_provider).to receive(:complete) do |_messages, **_kwargs, &block|
      block.call(RubyLLM::Chunk.new(role: :assistant, content: 'primary partial', model_id: 'primary-model'))
      raise RubyLLM::ServiceUnavailableError.new(nil, 'stream failed')
    end
    allow(fallback_provider).to receive(:complete) do |_messages, **_kwargs, &block|
      block.call(RubyLLM::Chunk.new(role: :assistant, content: 'fallback chunk', model_id: 'fallback-model'))
      RubyLLM::Message.new(role: :assistant, content: 'fallback final', model_id: 'fallback-model')
    end

    lifecycle = []
    chunks = []
    chat.before_message { lifecycle << [:before_message, chat.model.id] }
    chat.after_message { |message| lifecycle << [:after_message, chat.model.id, message.content] }
    chat.before_fallback do |event|
      lifecycle << [:before_fallback, event.from.id, event.to.id, event.chunks_yielded?]
    end
    chat.after_fallback do |event|
      lifecycle << [:after_fallback, event.to.id, event.succeeded?]
    end

    chat.ask_later('Hello')
    response = chat.generate { |chunk| chunks << [chat.model.id, chunk.content] }

    expect(response.content).to eq('fallback final')
    expect(chunks).to eq([
                           ['primary-model', 'primary partial'],
                           ['fallback-model', 'fallback chunk']
                         ])
    expect(lifecycle).to eq([
                              [:before_message, 'primary-model'],
                              [:before_fallback, 'primary-model', 'fallback-model', true],
                              [:before_message, 'fallback-model'],
                              [:after_message, 'fallback-model', 'fallback final'],
                              [:after_fallback, 'fallback-model', true]
                            ])
  end
end
