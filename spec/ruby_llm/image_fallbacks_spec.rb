# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Image do
  let(:instrumenter) { CaptureInstrumenter.new }
  let(:context) do
    RubyLLM.context do |config|
      config.openai_api_key = 'test'
      config.gemini_api_key = 'test'
      config.instrumenter = instrumenter
    end
  end
  let(:openai_model) { model_for(:openai, :image) }
  let(:gemini_model) { model_for(:gemini, :image) }

  def openai_url = 'https://api.openai.com/v1/images/generations'

  def gemini_url = "https://generativelanguage.googleapis.com/v1beta/models/#{gemini_model}:generateContent"

  def json(body, status: 200)
    { status:, headers: { 'Content-Type' => 'application/json' }, body: body.to_json }
  end

  def rate_limited
    json({ error: { message: 'Slow down', type: 'rate_limit_error' } }, status: 429)
  end

  def gemini_image
    json({ candidates: [{ content: { parts: [{ inlineData: { mimeType: 'image/png', data: 'aGk=' } }] },
                          finishReason: 'STOP' }],
           usageMetadata: { promptTokenCount: 4, candidatesTokenCount: 9 } })
  end

  def paint(context: self.context, **)
    described_class.paint('A paper boat', model: openai_model, provider: :openai, context:, **)
  end

  def usage_events
    instrumenter.events.filter_map { |name, payload| payload if name == 'usage.ruby_llm' }
  end

  it 'paints with the next model when the first is rate limited' do
    stub_request(:post, openai_url).to_return(rate_limited)
    stub_request(:post, gemini_url).to_return(gemini_image)

    image = paint(fallbacks: [gemini_model])

    expect(image).to have_attributes(data: 'aGk=', model: gemini_model)
    expect(usage_events.map { |usage| usage.values_at(:provider, :model, :status) })
      .to eq([['openai', openai_model, :failed], ['gemini', gemini_model, :succeeded]])
    expect(instrumenter.events.filter_map { |name, payload| payload[:model] if name == 'image.ruby_llm' })
      .to eq([gemini_model])
  end

  it 'takes a Model and a provider, as Chat#with_fallbacks does' do
    stub_request(:post, openai_url).to_return(rate_limited)
    stub_request(:post, gemini_url).to_return(gemini_image)

    expect(paint(fallbacks: RubyLLM.models.find(gemini_model, provider: :gemini)).model).to eq(gemini_model)
  end

  it 'paints with a fallback Model as given, without looking it up again' do
    stub_request(:post, openai_url).to_return(rate_limited)
    stub_request(:post, gemini_url).to_return(gemini_image)
    custom = RubyLLM::Model.default(gemini_model, 'gemini')
    allow(RubyLLM::Models).to receive(:resolve).and_call_original

    paint(fallbacks: custom)

    expect(RubyLLM::Models).not_to have_received(:resolve).with(custom, anything)
    expect(instrumenter.events.find { |name, _| name == 'image.ruby_llm' }.last[:model_info]).to equal(custom)
  end

  it 'skips a fallback whose model does not exist' do
    stub_request(:post, openai_url).to_return(rate_limited)
    stub_request(:post, gemini_url).to_return(gemini_image)
    allow(RubyLLM.logger).to receive(:warn)

    expect(paint(fallbacks: ['no-such-image-model', gemini_model]).model).to eq(gemini_model)
    expect(RubyLLM.logger).to have_received(:warn).with(/skipped fallback no-such-image-model/)
  end

  it 'raises the last error when every model fails' do
    stub_request(:post, openai_url).to_return(rate_limited)
    stub_request(:post, gemini_url).to_return(json({ error: { code: 503, message: 'Busy' } }, status: 503))

    expect { paint(fallbacks: [gemini_model]) }.to raise_error(RubyLLM::ServiceUnavailableError)
    expect(usage_events.map { |usage| usage[:status] }).to eq(%i[failed failed])
  end

  it 'raises an error that is not transient without trying the fallbacks' do
    stub_request(:post, openai_url).to_return(json({ error: { message: 'Bad prompt' } }, status: 400))
    fallback = stub_request(:post, gemini_url).to_return(gemini_image)

    expect { paint(fallbacks: [gemini_model]) }.to raise_error(RubyLLM::BadRequestError)
    expect(fallback).not_to have_been_requested
  end

  describe 'with retries configured' do
    let(:retrying) do
      RubyLLM.context do |config|
        config.openai_api_key = 'test'
        config.gemini_api_key = 'test'
        config.max_retries = 2
        config.instrumenter = instrumenter
      end
    end

    # The waits are not slept, so the last model's long one costs nothing.
    before do
      allow(Faraday::Retry::Middleware).to receive(:new).and_wrap_original do |constructor, *args|
        constructor.call(*args).tap { |middleware| allow(middleware).to receive(:sleep) }
      end
    end

    def rate_limited_for(seconds)
      rate_limited.merge(headers: { 'Content-Type' => 'application/json', 'Retry-After' => seconds })
    end

    it 'paints with the next model instead of waiting out a long Retry-After' do
      openai = stub_request(:post, openai_url).to_return(rate_limited_for('20'))
      stub_request(:post, gemini_url).to_return(gemini_image)

      image = paint(fallbacks: [gemini_model], context: retrying)

      expect(image.model).to eq(gemini_model)
      expect(openai).to have_been_requested.once
    end

    it 'retries the same model when the wait is short' do
      openai = stub_request(:post, openai_url).to_return(rate_limited_for('0.1'))
      stub_request(:post, gemini_url).to_return(gemini_image)

      expect(paint(fallbacks: [gemini_model], context: retrying).model).to eq(gemini_model)
      expect(openai).to have_been_requested.times(3)
    end

    it 'waits out a long Retry-After on the last model' do
      stub_request(:post, openai_url).to_return(rate_limited)
      gemini = stub_request(:post, gemini_url).to_return(rate_limited_for('20'))

      expect { paint(fallbacks: [gemini_model], context: retrying) }.to raise_error(RubyLLM::RateLimitError)
      expect(gemini).to have_been_requested.times(3)
    end
  end

  it 'raises the error without fallbacks, as before' do
    stub_request(:post, openai_url).to_return(rate_limited)

    expect { paint }.to raise_error(RubyLLM::RateLimitError)
  end
end
