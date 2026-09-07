# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter::Embeddings do
  let(:protocol) { RubyLLM::Providers::OpenRouter::ChatCompletions.allocate }
  let(:model) { model_for(:openrouter, :multimodal_embedding) }
  let(:image) { RubyLLM::Attachment.new('https://example.com/logo.png') }

  def render(text, **options)
    protocol.send(:render_embedding_payload, text, model:, dimensions: nil, **options)
  end

  it 'embeds text and an image as one input' do
    expect(render('The Ruby logo', with: [image])).to eq(
      model: model,
      input: [{ content: [
        { type: 'text', text: 'The Ruby logo' },
        { type: 'image_url', image_url: { url: 'https://example.com/logo.png' } }
      ] }]
    )
  end

  it 'embeds an image without text' do
    expect(render(nil, with: [image])[:input]).to eq(
      [{ content: [{ type: 'image_url', image_url: { url: 'https://example.com/logo.png' } }] }]
    )
  end

  it 'encodes local images' do
    attachment = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__))
    part = render(nil, with: [attachment]).dig(:input, 0, :content, 0)

    expect(part.dig(:image_url, :url)).to start_with('data:image/png;base64,')
  end

  it 'preserves batched text inputs and maps the task type' do
    expect(render(%w[Ruby Rails], task_type: 'search_document')).to eq(
      model: model, input: %w[Ruby Rails], input_type: 'search_document'
    )
  end

  { 'sample.pdf' => 'input_file', 'ruby.mp4' => 'input_video', 'ruby.wav' => 'input_audio' }.each do |filename, type|
    it "renders #{type} using the embedding media format" do
      attachment = RubyLLM::Attachment.new(File.expand_path("../../../fixtures/#{filename}", __dir__))

      expect(render(nil, with: [attachment])[:input]).to eq(
        [{ content: [{ type: type, type.to_sym => { data: attachment.for_llm, format: attachment.format } }] }]
      )
    end
  end

  it 'rejects provider-managed references without inline content' do
    file = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'report.pdf', mime_type: 'application/pdf')

    expect { render(nil, with: RubyLLM::Attachment.wrap(file)) }
      .to raise_error(RubyLLM::UnsupportedAttachmentError)
  end

  it 'allows provider options to override rendered fields' do
    expect(render('Ruby', task_type: 'search_document',
                          provider_options: { input_type: 'search_query', dimensions: 256 })).to eq(
                            model: model, input: 'Ruby', input_type: 'search_query', dimensions: 256
                          )
  end

  it 'rejects ambiguous attachment and multiple-text combinations' do
    expect { render(%w[Ruby Rails], with: [image]) }.to raise_error(ArgumentError, /one text at a time/)
  end

  it 'accepts attachments through the public API and returns one vector' do
    request = stub_request(:post, 'https://openrouter.ai/api/v1/embeddings')
              .with(body: { model: model, input: [{ content: [
                      { type: 'text', text: 'The Ruby logo' },
                      { type: 'image_url', image_url: { url: 'https://example.com/logo.png' } }
                    ] }] })
              .to_return_json(body: { data: [{ embedding: [0.1, 0.2] }],
                                      usage: { prompt_tokens: 12, cost: 0.0001 } })

    context = RubyLLM.context { |config| config.openrouter_api_key = 'test-key' }
    result = context.embed('The Ruby logo', model:, provider: :openrouter, with: image)

    expect(request).to have_been_requested.once
    expect(result.vectors).to eq([0.1, 0.2])
    expect(result.tokens.input).to eq(12)
    expect(result.cost.total).to eq(0.0001)
  end
end
