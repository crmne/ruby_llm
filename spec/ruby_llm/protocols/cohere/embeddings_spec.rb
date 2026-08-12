# frozen_string_literal: true

require 'spec_helper'

# Fixtures follow the request and response examples published at
# https://docs.cohere.com/reference/embed.
RSpec.describe RubyLLM::Protocols::Cohere::Embeddings do
  let(:protocol) { Object.new.extend(described_class) }
  let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }

  def render(text, **options)
    protocol.send(:render_embedding_payload, text, model: 'embed-v4.0', dimensions: nil, **options)
  end

  describe '#embedding_url' do
    it 'posts to the v2 embed endpoint' do
      expect(protocol.send(:embedding_url, model: 'embed-v4.0')).to eq('v2/embed')
    end
  end

  describe '#render_embedding_payload' do
    it 'renders texts with the required input type and float embeddings' do
      expect(render(%w[hello goodbye])).to eq(
        model: 'embed-v4.0',
        input_type: 'search_document',
        embedding_types: ['float'],
        texts: %w[hello goodbye]
      )
    end

    it 'wraps a single text in the texts array' do
      expect(render('hello')[:texts]).to eq(['hello'])
    end

    it 'passes task_type through as the input type' do
      expect(render('hello', task_type: 'search_query')[:input_type]).to eq('search_query')
    end

    it 'requests a custom output dimension' do
      expect(render('hello', dimensions: 256)[:output_dimension]).to eq(256)
    end

    it 'sends text and images as multimodal inputs' do
      payload = render('a red gem', with: [RubyLLM::Attachment.new(image_path)])

      expect(payload).not_to have_key(:texts)
      expect(payload[:inputs].first[:content].first).to eq(type: 'text', text: 'a red gem')
      expect(payload[:inputs].first[:content].last).to match(
        type: 'image_url', image_url: { url: a_string_starting_with('data:image/png;base64,') }
      )
    end

    it 'embeds one text at a time alongside attachments' do
      expect { render(%w[one two], with: [RubyLLM::Attachment.new(image_path)]) }
        .to raise_error(ArgumentError, /one text at a time/)
    end

    it 'lets provider options override the rendered payload' do
      expect(render('hello', provider_options: { truncate: 'START' })).to include(truncate: 'START')
    end
  end

  describe '#supports_embedding_media?' do
    it 'accepts attachments' do
      expect(protocol.send(:supports_embedding_media?)).to be(true)
    end
  end

  describe '#parse_embedding_response' do
    let(:body) do
      {
        'id' => 'da6e531f-54c6-4a73-bf92-f60566d8d753',
        'embeddings' => { 'float' => [[0.016296387, -0.008354187], [0.045806885, -0.03125]] },
        'texts' => %w[hello goodbye],
        'meta' => { 'billed_units' => { 'input_tokens' => 2 } }
      }
    end

    it 'returns one vector per text' do
      embedding = protocol.send(:parse_embedding_response, response(body), model: 'embed-v4.0', text: %w[hello goodbye])

      expect(embedding.vectors).to eq([[0.016296387, -0.008354187], [0.045806885, -0.03125]])
      expect(embedding.tokens.input).to eq(2)
    end

    it 'flattens the single vector of a single text' do
      body['embeddings']['float'] = [[0.016296387, -0.008354187]]

      embedding = protocol.send(:parse_embedding_response, response(body), model: 'embed-v4.0', text: 'hello')

      expect(embedding.vectors).to eq([0.016296387, -0.008354187])
    end
  end

  def response(body)
    instance_double(Faraday::Response, body: body)
  end
end
