# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol::BinaryStreaming do
  let(:attempts) { [] }
  let(:audio) { "ID3#{'audio' * 20}".b }
  let(:responses) do
    [{ status: 503, content_type: 'text/plain', chunks: ['upstream connect error'] },
     { status: 200, content_type: 'audio/mpeg', chunks: [audio[0, 40], audio[40..]] }]
  end
  let(:context) do
    RubyLLM.context do |config|
      config.openai_api_key = 'test'
      config.faraday_adapter = adapter(expose_env)
      config.max_retries = responses.length - 1
      config.retry_interval = 0
      config.retry_interval_randomness = 0
    end
  end

  def adapter(with_env)
    scripted_responses = responses
    requests = attempts

    Class.new(Faraday::Adapter) do
      define_method(:call) do |env|
        super(env)
        response = scripted_responses.fetch(requests.length)
        requests << env
        env.status = response.fetch(:status)
        env.response_headers = Faraday::Utils::Headers.new('content-type' => response.fetch(:content_type))
        bytes = 0
        response.fetch(:chunks).each do |chunk|
          bytes += chunk.bytesize
          env.request.on_data.call(chunk, bytes, with_env ? env : nil)
        end

        save_response(env, response.fetch(:status), nil, { 'content-type' => response.fetch(:content_type) })
        @app.call(env)
      end
    end
  end

  [['without a response environment', false],
   ['with a response environment', true]].each do |mode, with_env|
    context "when streaming #{mode}" do
      let(:expose_env) { with_env }

      it 'returns only the audio of the attempt that succeeded' do
        chunks = []

        speech = context.speak('Hello', model: model_for(:openai, :speech), provider: :openai) do |chunk|
          chunks << chunk.data
        end

        expect(attempts.size).to eq(2)
        expect(speech.to_blob).to eq(audio)
        expect(chunks.join).to eq(audio)
      end
    end
  end
end
