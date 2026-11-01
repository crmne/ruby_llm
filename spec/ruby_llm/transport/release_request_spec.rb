# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transport::ReleaseRequest do
  def get(status:, body: '{}')
    connection = RubyLLM::Transport::Connection.basic do |faraday|
      faraday.use RubyLLM::Transport::JsonResponse
      faraday.adapter(:test) { |stubs| stubs.get('/') { [status, { 'Content-Type' => 'application/json' }, body] } }
    end
    connection.get('https://api.example.test/') { |request| request.headers['x-goog-api-key'] = 'secret-key' }
  end

  it 'drops the key from a Faraday error' do
    expect { get(status: 401) }.to raise_error(Faraday::UnauthorizedError) do |error|
      expect(error.response).not_to have_key(:request)
    end
  end

  it 'drops the key from a RubyLLM error' do
    expect { get(status: 200, body: '{') }.to raise_error(RubyLLM::Error) do |error|
      expect(error.response.env.request_headers).to be_empty
    end
  end

  it 'clears everything the request held' do
    request = Faraday::RequestOptions.new(context: { secret: true }, on_data: proc {})
    env = Faraday::Env.from(request:, request_body: 'prompt', request_headers: { 'x-api-key' => 'secret-key' })

    expect(described_class.release(env)).to be(env)
    expect(env.to_h.values_at(:request_body, :request_headers)).to eq([nil, {}])
    expect(env.request.to_h.values_at(:context, :on_data)).to eq([nil, nil])
  end

  it 'leaves a successful request alone' do
    expect(get(status: 200).env.request_headers['x-goog-api-key']).to eq('secret-key')
  end
end
