# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol::Streaming do
  let(:attempts) { [] }
  let(:successful_reads) do
    completed = { type: 'response.completed', response: { model: model_for(:openai), status: 'completed', error: nil,
                                                          usage: { input_tokens: 10, output_tokens: 7 } } }
    ["data: #{JSON.generate(type: 'response.output_text.delta', delta: 'Hello')}\n\n",
     "event: response.completed\ndata: ",
     "#{JSON.generate(completed)}\n\n"]
  end
  let(:responses) do
    [{ chunks: ["{\n"], error: Faraday::ConnectionFailed.new('Connection lost') }, { chunks: successful_reads }]
  end
  let(:chat) do
    RubyLLM.context do |config|
      config.openai_api_key = 'test'
      config.openai_protocol = :responses
      config.faraday_adapter = adapter(expose_env)
      config.max_retries = responses.length - 1
      config.retry_interval = 0
      config.retry_interval_randomness = 0
    end.chat(model: model_for(:openai), provider: :openai)
  end

  def adapter(with_env)
    scripted_responses = responses
    requests = attempts

    Class.new(Faraday::Adapter) do
      define_method(:call) do |env|
        super(env)
        response = scripted_responses.fetch(requests.length)
        requests << env
        env.status = 200
        bytes = 0
        response.fetch(:chunks).each do |chunk|
          bytes += chunk.bytesize
          if Faraday::VERSION.start_with?('1')
            env.request.on_data.call(chunk, bytes)
          else
            env.request.on_data.call(chunk, bytes, with_env ? env : nil)
          end
        end
        raise response[:error] if response[:error]

        save_response(env, 200, nil, { 'content-type' => 'text/event-stream' })
        @app.call(env)
      end
    end
  end

  [['without a response environment', false, nil],
   ['with a response environment', true, nil],
   ['with a Faraday 1 callback', false, '1.10.4']].each do |mode, with_env, version|
    context "when streaming #{mode}" do
      let(:expose_env) { with_env }

      before { stub_const('Faraday::VERSION', version) if version }

      it 'delivers text and usage after an interrupted JSON body' do
        chunks = []

        message = chat.ask('Hello') { |chunk| chunks << chunk }

        expect(attempts.size).to eq(2)
        expect(chunks.filter_map(&:content)).to eq(['Hello'])
        expect(message.content).to eq('Hello')
        expect(message.tokens.output).to eq(7)
        expect(message.ruby_llm_usage_entries.map(&:status)).to eq(%i[failed succeeded])
        expect(message.raw.env.request.context).not_to have_key(RubyLLM::Transport::ErrorMiddleware::STREAM_RESET_KEY)
      end

      it 'discards a partially parsed SSE event before retrying' do
        responses.first[:chunks] = [": keepalive\n\ndata: {\"type\":"]

        message = chat.ask('Hello') { |_chunk| nil }

        expect(attempts.size).to eq(2)
        expect(message.content).to eq('Hello')
        expect(message.tokens.output).to eq(7)
      end

      it 'raises a JSON error returned after an interrupted SSE event' do
        responses.first[:chunks] = [": keepalive\n\ndata: {\"type\":"]
        responses[1] = { chunks: ['{"error":{"message":"Service busy","type":"server_error"}}'] }

        expect { chat.ask('Hello') { raise 'No chunks should be delivered' } }
          .to raise_error(RubyLLM::ServerError, 'Service busy')
        expect(attempts.size).to eq(2)
      end

      it 'raises a JSON error returned after an interrupted JSON body' do
        responses.first[:chunks] = ['{"error":']
        responses[1] = { chunks: ['{"error":{"message":"Service busy","type":"server_error"}}'] }

        expect { chat.ask('Hello') { raise 'No chunks should be delivered' } }
          .to raise_error(RubyLLM::ServerError, 'Service busy')
        expect(attempts.size).to eq(2)
      end

      it 'starts fresh after successive interrupted bodies' do
        responses.insert(1, { chunks: [": keepalive\n\ndata: {\"type\":"],
                              error: Faraday::TimeoutError.new('Read timed out') })

        message = chat.ask('Hello') { |_chunk| nil }

        expect(attempts.size).to eq(3)
        expect(message.content).to eq('Hello')
        expect(message.tokens.output).to eq(7)
        expect(message.ruby_llm_usage_entries.map(&:status)).to eq(%i[failed failed succeeded])
      end

      it 'does not retry a connection failure after delivering text' do
        responses.first[:chunks] = [successful_reads.first]
        chunks = []

        expect { chat.ask('Hello') { |chunk| chunks << chunk.content } }
          .to raise_error(Faraday::ConnectionFailed, 'Connection lost')
        expect(attempts.size).to eq(1)
        expect(chunks).to eq(['Hello'])
      end
    end
  end
end
