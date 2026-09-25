# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transport::JsonResponse do
  def response_for(body, content_type: 'application/json', status: 200, **options)
    headers = { 'Content-Type' => content_type }.compact

    Faraday.new do |connection|
      connection.use described_class, **options
      connection.adapter :test do |stubs|
        stubs.get('/') { [status, headers, body] }
      end
    end.get('/')
  end

  it 'decodes JSON responses with string keys' do
    expect(response_for('{"content":"Hello"}').body).to eq('content' => 'Hello')
  end

  it 'decodes JSON media types with a suffix and charset' do
    response = response_for('{"content":"Hello"}', content_type: 'application/problem+json; charset=utf-8')

    expect(response.body).to eq('content' => 'Hello')
  end

  it 'passes parser options as keywords when reading model catalogs' do
    response = response_for('[{"id":"gpt-5-nano"}]', parser_options: { symbolize_names: true })

    expect(response.body).to eq([{ id: 'gpt-5-nano' }])
  end

  it 'returns nil for an empty response' do
    expect(response_for('').body).to be_nil
  end

  it 'returns nil for a whitespace-only response' do
    expect(response_for(" \n").body).to be_nil
  end

  it 'preserves a nil body for a response without content' do
    expect(response_for(nil, status: 204).body).to be_nil
  end

  it 'wraps malformed JSON in a Faraday parsing error' do
    expect { response_for('{', preserve_raw: true) }.to raise_error(Faraday::ParsingError) do |error|
      expect(error.wrapped_exception).to be_a(JSON::ParserError)
      expect(error.response.body).to eq('{')
      expect(error.response.env[:raw_body]).to eq('{')
    end
  end

  it 'wraps invalid UTF-8 responses in a Faraday parsing error' do
    body = "\xFF"

    expect { response_for(body) }.to raise_error(Faraday::ParsingError)
  end

  it 'wraps incomplete multibyte responses in a Faraday parsing error' do
    body = '{'.dup.force_encoding(Encoding::UTF_16LE)

    expect { response_for(body) }.to raise_error(Faraday::ParsingError)
  end

  it 'leaves already parsed responses untouched' do
    body = { 'content' => 'Hello' }

    expect(response_for(body).body).to equal(body)
  end

  it 'leaves non-JSON responses unparsed' do
    body = '{"content":"Hello"}'

    expect(response_for(body, content_type: 'text/plain').body).to eq(body)
  end

  it 'leaves responses without a content type unparsed' do
    body = '{"content":"Hello"}'

    expect(response_for(body, content_type: nil).body).to eq(body)
  end

  it 'leaves streaming responses unparsed' do
    body = "data: {\"content\":\"Hello\"}\n\n"

    expect(response_for(body, content_type: 'text/event-stream').body).to eq(body)
  end

  it 'preserves the original response when requested' do
    body = '{"content":"Hello"}'
    response = response_for(body, preserve_raw: true)

    expect(response.body).to eq('content' => 'Hello')
    expect(response.env[:raw_body]).to eq(body)
  end
end
