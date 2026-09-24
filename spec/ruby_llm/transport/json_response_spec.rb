# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transport::JsonResponse do
  def response_for(body, content_type: 'application/json', status: 200, **options)
    Faraday.new do |connection|
      connection.use described_class, **options
      connection.adapter :test do |stubs|
        stubs.get('/') { [status, { 'Content-Type' => content_type }, body] }
      end
    end.get('/')
  end

  it 'decodes JSON responses with string keys' do
    expect(response_for('{"content":"Hello"}').body).to eq('content' => 'Hello')
  end

  it 'passes parser options as keywords when reading model catalogs' do
    response = response_for('[{"id":"gpt-5-nano"}]', parser_options: { symbolize_names: true })

    expect(response.body).to eq([{ id: 'gpt-5-nano' }])
  end

  it 'returns nil for an empty response' do
    expect(response_for(" \n").body).to be_nil
  end

  it 'preserves a nil body for a response without content' do
    expect(response_for(nil, status: 204).body).to be_nil
  end

  it 'wraps malformed JSON in a Faraday parsing error' do
    expect { response_for('{') }.to raise_error(Faraday::ParsingError)
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
