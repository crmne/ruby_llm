# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transport::Connection do
  include_context 'with configured RubyLLM'

  let(:status) { 200 }
  let(:adapter) do
    status = self.status
    Class.new(Faraday::Adapter) do
      define_method(:call) do |env|
        super(env)
        env.request.on_data.call("data: {}\n\n", 10, env) if env.request.stream_response?
        save_response(env, status, '{"ok":true}', { 'Content-Type' => 'application/json' })
        @app.call(env)
      end
    end
  end
  let(:transport) do
    config = RubyLLM.config.dup.tap do |copy|
      copy.faraday_adapter = adapter
      copy.openai_api_key = 'sk-secret-key'
      copy.max_retries = 0
    end
    RubyLLM::Providers::OpenAI.new(config).connection
  end

  it 'returns a response that keeps no copy of the request body' do
    response = transport.post('chat/completions', { messages: [{ role: 'user', content: 'history ' * 1000 }] })

    expect(response.env.request_body).to be_nil
    expect(response).to have_attributes(status: 200, body: { 'ok' => true })
  end

  it 'lets go of the streaming callback once the stream ends' do
    chunks = []
    response = transport.post('chat/completions', {}, stream: true) do |request|
      request.options.on_data = proc { |chunk| chunks << chunk }
    end

    expect(chunks).to eq(["data: {}\n\n"])
    expect(response.env.request.on_data).to be_nil
  end

  def keeps_no_request?(env)
    env.request_body.nil? && env.request_headers.empty? && env.request.context.nil? &&
      !env.inspect.include?('sk-secret-key')
  end

  it 'returns responses to every verb without the request headers or context' do
    responses = [transport.post('chat/completions', { model: 'm' }), transport.get('models'),
                 transport.patch('files/f', {}), transport.delete('files/f')]

    expect(responses.map { |response| keeps_no_request?(response.env) }).to all(be(true))
  end

  context 'when the provider refuses the request' do
    let(:status) { 401 }

    it 'raises an error whose response keeps no request' do
      expect { transport.post('chat/completions', { input: 'private prompt' }) }
        .to raise_error(RubyLLM::UnauthorizedError) { |error| expect(keeps_no_request?(error.response)).to be(true) }
    end
  end
end
