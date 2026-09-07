# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure::ChatCompletions do
  let(:api_base) { 'https://contoso.services.ai.azure.com' }
  let(:context) do
    RubyLLM.context do |config|
      config.azure_api_base = api_base
      config.azure_api_key = 'test-key'
    end
  end
  let(:provider) { RubyLLM::Providers::Azure.new(context.config) }
  let(:protocol) { described_class.new(provider) }

  before do
    stub_request(:any, %r{\Ahttps://contoso[.]}).to_raise('Unexpected Azure request')
  end

  def image_model = model_for(:azure, :azure_image)
  def speech_model = model_for(:azure, :azure_speech)
  def transcription_model = model_for(:azure, :azure_transcription)
  def image_path = File.expand_path('../../../fixtures/ruby.png', __dir__)
  def audio_path = File.expand_path('../../../fixtures/ruby.wav', __dir__)

  {
    'https://contoso.services.ai.azure.com' => ['https://contoso.services.ai.azure.com/openai/v1', 'preview'],
    'https://contoso.openai.azure.com/openai/v1' => ['https://contoso.openai.azure.com/openai/v1', 'preview'],
    'https://contoso.openai.azure.com/openai/v1/?api-version=preview' =>
      ['https://contoso.openai.azure.com/openai/v1', 'preview'],
    'https://contoso.openai.azure.com/openai/deployments/media' =>
      ['https://contoso.openai.azure.com/openai/deployments/media', '2025-04-01-preview'],
    'https://contoso.openai.azure.com/openai/deployments/media?api-version=2024-10-21' =>
      ['https://contoso.openai.azure.com/openai/deployments/media', '2024-10-21'],
    'https://contoso.openai.azure.com/openai/deployments/media/chat/completions?api-version=2025-04-01-preview' =>
      ['https://contoso.openai.azure.com/openai/deployments/media', '2025-04-01-preview']
  }.each do |base, (root, version)|
    context "with #{base}" do
      let(:api_base) { base }

      it 'resolves image generation, image edits, speech and transcription endpoints' do
        expect(protocol.images_url).to eq("#{root}/images/generations?api-version=#{version}")
        expect(protocol.images_url(with: image_path)).to eq("#{root}/images/edits?api-version=#{version}")
        expect(protocol.speech_url(model: speech_model)).to eq("#{root}/audio/speech?api-version=#{version}")
        expect(protocol.transcription_url).to eq("#{root}/audio/transcriptions?api-version=#{version}")
      end

      it 'posts to the resolved URL without duplicating base paths or API versions' do
        request = stub_request(:post, "#{root}/audio/speech?api-version=#{version}")
                  .with(body: { model: speech_model, input: 'Hello', voice: 'alloy', response_format: 'mp3' })
                  .to_return(body: 'audio bytes', headers: { 'Content-Type' => 'audio/mpeg' })

        result = context.speak('Hello', model: speech_model, provider: :azure, format: 'mp3')

        expect(request).to have_been_requested.once
        expect(result.data).to eq('audio bytes')
      end
    end
  end

  it 'generates images through the public API from a resource base' do
    request = stub_request(:post, "#{api_base}/openai/v1/images/generations?api-version=preview")
              .with(headers: { 'api-key' => 'test-key' }, body: {
                      model: image_model, prompt: 'A ruby', n: 1, size: '1024x1024', quality: 'low'
                    })
              .to_return_json(body: { data: [{ b64_json: Base64.strict_encode64('image bytes') }] })

    result = context.paint('A ruby', model: image_model, provider: :azure, size: '1024x1024',
                                     provider_options: { quality: 'low' })

    expect(request).to have_been_requested.once
    expect(result).to be_a(RubyLLM::Image)
    expect(result.data).to eq(Base64.strict_encode64('image bytes'))
  end

  it 'edits GPT images as multipart uploads with size, count and mask' do
    payload = protocol.send(:render_image_payload, 'Make it green', model: image_model, size: '1024x1536',
                                                                    count: 2, with: image_path, mask: image_path)

    expect(payload).to include(model: image_model, prompt: 'Make it green', n: 2, size: '1024x1536')
    expect(payload[:image]).to be_a(Faraday::UploadIO)
    expect(payload[:mask]).to be_a(Faraday::UploadIO)
    expect(payload).not_to have_key(:images)
  end

  it 'keeps image and audio dialects when Responses is selected' do
    responses = RubyLLM::Providers::Azure::Responses.new(provider)
    payload = responses.send(:render_image_payload, 'Make it green', model: image_model,
                                                                     size: '1024x1024', with: image_path)

    expect(responses.images_url(with: image_path)).to eq("#{api_base}/openai/v1/images/edits?api-version=preview")
    expect(responses.speech_url(model: speech_model)).to eq("#{api_base}/openai/v1/audio/speech?api-version=preview")
    expect(responses.transcription_url).to eq("#{api_base}/openai/v1/audio/transcriptions?api-version=preview")
    expect(payload[:image]).to be_a(Faraday::UploadIO)
  end

  it 'preserves explicit image options and custom deployment names' do
    payload = protocol.send(:render_image_payload, 'Make it green', model: 'production-images', size: '1024x1024',
                                                                    with: [image_path, image_path],
                                                                    provider_options: { size: '1536x1024', n: 3 })

    expect(payload).to include(model: 'production-images', size: '1536x1024', n: 3)
    expect(payload[:image].size).to eq(2)
    expect(payload[:image]).to all(be_a(Faraday::UploadIO))
  end

  it 'sends a multipart edit through the public API' do
    request = stub_request(:post, "#{api_base}/openai/v1/images/edits?api-version=preview")
              .with do |req|
                req.headers['Content-Type'].start_with?('multipart/form-data') &&
                  req.body.include?('name="image"; filename="ruby.png"') &&
                  req.body.include?("name=\"size\"\r\n\r\n1024x1024")
              end
              .to_return_json(body: { data: [{ b64_json: Base64.strict_encode64('edited bytes') }] })

    result = context.paint('Make it green', model: image_model, provider: :azure, with: image_path, size: '1024x1024')

    expect(request).to have_been_requested.once
    expect(result).to be_a(RubyLLM::Image)
  end

  it 'synthesizes speech through the public API' do
    request = stub_request(:post, "#{api_base}/openai/v1/audio/speech?api-version=preview")
              .with(body: { model: speech_model, input: 'Hello Ruby', voice: 'alloy', response_format: 'wav' })
              .to_return(body: 'audio bytes', headers: { 'Content-Type' => 'audio/wav' })

    result = context.speak('Hello Ruby', model: speech_model, provider: :azure, format: 'wav')

    expect(request).to have_been_requested.once
    expect(result.data).to eq('audio bytes')
    expect(result.format).to eq('wav')
  end

  it 'transcribes audio through the public API' do
    request = stub_request(:post, "#{api_base}/openai/v1/audio/transcriptions?api-version=preview")
              .with do |req|
                req.body.include?('name="file"; filename="ruby.wav"') &&
                  req.body.include?("name=\"language\"\r\n\r\nen") &&
                  req.body.include?("name=\"prompt\"\r\n\r\nRuby")
              end
              .to_return_json(body: { text: 'Ruby is a language.', usage: { input_tokens: 12, output_tokens: 5 } })

    result = context.transcribe(audio_path, model: transcription_model, provider: :azure,
                                            language: 'en', prompt: 'Ruby')

    expect(request).to have_been_requested.once
    expect(result.text).to eq('Ruby is a language.')
    expect(result.tokens.input).to eq(12)
  end

  it 'preserves diarized segments for a custom deployment' do
    request = stub_request(:post, "#{api_base}/openai/v1/audio/transcriptions?api-version=preview")
              .with { |req| req.body.include?("name=\"response_format\"\r\n\r\ndiarized_json") }
              .to_return_json(body: { text: 'Hello', segments: [{ text: 'Hello', speaker: 'A', start: 0, end: 1 }] })

    result = context.transcribe(audio_path, model: 'meeting-transcriber', provider: :azure, format: 'diarized_json')

    expect(request).to have_been_requested.once
    expect(result.segments.first).to include('speaker' => 'A', 'text' => 'Hello')
  end

  it 'streams prerecorded audio through the Azure transcription endpoint' do
    events = [{ type: 'transcript.text.delta', delta: 'Hello' },
              { type: 'transcript.text.done', text: 'Hello', usage: { input_tokens: 12, output_tokens: 1 } }]
    request = stub_request(:post, "#{api_base}/openai/v1/audio/transcriptions?api-version=preview")
              .with { |req| req.body.include?("name=\"stream\"\r\n\r\ntrue") }
              .to_return(body: events.map { |event| "data: #{JSON.generate(event)}\n\n" }.join,
                         headers: { 'Content-Type' => 'text/event-stream' })
    chunks = []

    result = context.transcribe(audio_path, model: transcription_model, provider: :azure) { |chunk| chunks << chunk }

    expect(request).to have_been_requested.once
    expect(chunks.first.delta).to eq('Hello')
    expect(result.text).to eq('Hello')
    expect(result.tokens.input).to eq(12)
  end
end
