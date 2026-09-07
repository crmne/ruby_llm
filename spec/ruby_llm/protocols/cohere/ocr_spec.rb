# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Cohere::OCR do
  let(:protocol) { Object.new.extend(described_class) }
  let(:model) { model_for(:cohere, :ocr) }
  let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }

  it 'sends remote images without downloading them' do
    payload = protocol.send(:render_ocr_payload, 'https://example.com/invoice.png', model:)

    expect(payload).to eq(model: model, output_format: 'markdown',
                          document: { type: 'image_url', image_url: 'https://example.com/invoice.png' })
  end

  it 'inlines local images and accepts blocks output with the single image page' do
    payload = protocol.send(:render_ocr_payload, image_path, model:, pages: [0],
                                                             provider_options: { output_format: 'blocks' })

    expect(payload[:document]).to eq(type: 'image_url', image_url: RubyLLM::Attachment.new(image_path).for_llm)
    expect(payload[:output_format]).to eq('blocks')
    expect(payload).not_to have_key(:pages)
  end

  it 'rejects PDFs that the public Parse API cannot accept' do
    expect { protocol.send(:render_ocr_payload, 'https://example.com/invoice.pdf', model:) }
      .to raise_error(RubyLLM::UnsupportedAttachmentError, %r{application/pdf})
  end

  it 'rejects page selections beyond the single image' do
    expect { protocol.send(:render_ocr_payload, image_path, model:, pages: [1]) }
      .to raise_error(ArgumentError, /one image/)
  end

  it 'normalizes Markdown while preserving image details, billed pages, and raw data' do
    image = { 'id' => 'img-0', 'description' => 'Ruby logo', 'bounding_box' => { 'top_left_x' => 12 } }
    page = { 'type' => 'markdown', 'index' => 0, 'markdown' => { 'content' => '# Ruby', 'images' => [image] } }
    body = { 'pages' => [page], 'meta' => { 'billed_units' => { 'pages' => 1 } } }

    result = protocol.send(:parse_ocr_response, instance_double(Faraday::Response, body:), model:)

    expect(result.pages.first).to have_attributes(markdown: '# Ruby', images: [image], raw: page)
    expect(result.raw).to equal(body)
    expect(result.usage).to eq('pages' => 1)
  end

  it 'preserves block order and exposes image and table metadata' do
    image = { 'id' => 'img-0', 'description' => 'Ruby logo' }
    table = { 'html' => '<table><tr><td>Ruby</td></tr></table>', 'bounding_box' => { 'top_left_x' => 3 } }
    page = { 'type' => 'blocks', 'index' => 0, 'blocks' => [
      { 'type' => 'text', 'text' => { 'content' => '# Languages' } },
      { 'type' => 'table', 'table' => table },
      { 'type' => 'image', 'image' => image }
    ] }

    response = instance_double(Faraday::Response, body: { 'pages' => [page] })
    result = protocol.send(:parse_ocr_response, response, model:)

    expect(result.markdown).to eq("# Languages\n\n#{table['html']}\n\n![Ruby logo](img-0)")
    expect(result.pages.first).to have_attributes(images: [image], tables: [table], raw: page)
  end

  %w[markdown blocks].each do |format|
    it "parses an image through the public OCR API with #{format} output", :live do
      result = RubyLLM.ocr(image_path, model:, provider: :cohere, provider_options: { output_format: format })

      expect(result.pages.size).to eq(1)
      expect(result.markdown).not_to be_empty
      expect(result.pages.first.images).not_to be_empty
      expect(result.pages.first.raw['type']).to eq(format)
      expect(result.pages.first.raw).to equal(result.raw['pages'].first)
      expect(result.usage['pages']).to eq(1)
    end
  end
end
