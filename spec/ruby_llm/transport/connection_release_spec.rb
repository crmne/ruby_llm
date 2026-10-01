# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transport::Connection do
  include_context 'with configured RubyLLM'

  let(:adapter) do
    Class.new(Faraday::Adapter) do
      def call(env)
        super
        env.request.on_data.call("data: {}\n\n", 10, env) if env.stream_response?
        save_response(env, 200, '{"ok":true}', { 'Content-Type' => 'application/json' })
        @app.call(env)
      end
    end
  end
  let(:transport) do
    config = RubyLLM.config.dup.tap { |copy| copy.faraday_adapter = adapter }
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
end
