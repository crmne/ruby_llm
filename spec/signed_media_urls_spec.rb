# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SignedMediaUrls do
  let(:url) { 'https://media.blob.core.windows.net/images/square.jpg?sv=2025-01-05&sig=secret%2Bsignature%3D&sp=r' }
  let(:filtered_url) { url.sub('secret%2Bsignature%3D', 'FILTERED_SIGNATURE') }

  it 'normalizes a generated URL, redirect, and matching download request consistently' do
    message = Struct.new(:uri, :body, :headers)
    interaction = Struct.new(:request, :response).new(
      message.new(url, '', {}),
      message.new(nil, JSON.generate(url: url), { 'Location' => [url] })
    )

    described_class.filter(interaction)
    expect(interaction.request.uri).to eq(filtered_url)
    expect(JSON.parse(interaction.response.body)['url']).to eq(filtered_url)
    expect(interaction.response.headers['Location']).to eq([filtered_url])
  end

  it 'filters signed URLs inside streamed and nested JSON text' do
    body = "data: #{JSON.generate(content: JSON.generate(url: url))}\n\n"
    expect(described_class.sanitize(body)).to eq(body.sub('secret%2Bsignature%3D', 'FILTERED_SIGNATURE'))
  end

  it 'leaves other hosts and ordinary signature fields unchanged' do
    text = "https://example.com/file?sig=public-value #{JSON.generate(sig: 'ordinary field')}"
    expect(described_class.sanitize(text)).to eq(text)
  end
end
