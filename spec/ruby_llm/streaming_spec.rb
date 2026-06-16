# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Streaming do
  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(described_class)
      obj.define_singleton_method(:build_chunk) { |data| "chunk:#{data['x']}" }
    end
  end

  let(:env) { Struct.new(:status).new(200) }

  before do
    stub_const('Faraday::VERSION', '2.0.0')
  end

  it 'skips non-hash SSE payloads' do
    yielded_chunks = []
    handler = test_obj.send(:handle_stream) { |chunk| yielded_chunks << chunk }

    expect { handler.call("data: true\n\n", 0, env) }.not_to raise_error
    expect(yielded_chunks).to eq([])
  end

  it 'processes hash SSE payloads' do
    yielded_chunks = []
    handler = test_obj.send(:handle_stream) { |chunk| yielded_chunks << chunk }

    handler.call("data: {\"x\":\"ok\"}\n\n", 0, env)

    expect(yielded_chunks).to eq(['chunk:ok'])
  end

  # Faraday 2 with the net_http adapter invokes on_data with a nil env (the
  # status is not yet known mid-stream). The handler must process such chunks
  # normally rather than treating them as a failed response and discarding them.
  it 'processes chunks when env is nil (status not yet known)' do
    yielded_chunks = []
    handler = test_obj.send(:handle_stream) { |chunk| yielded_chunks << chunk }

    handler.call("data: {\"x\":\"ok\"}\n\n", 0, nil)

    expect(yielded_chunks).to eq(['chunk:ok'])
  end

  describe RubyLLM::Streaming::FaradayHandlers do
    describe '.v2_on_data' do
      let(:on_chunk_calls) { [] }
      let(:on_failed_calls) { [] }
      let(:handler) do
        described_class.v2_on_data(
          ->(chunk, env) { on_chunk_calls << [chunk, env] },
          ->(chunk, env) { on_failed_calls << [chunk, env] }
        )
      end

      it 'routes the chunk to on_chunk when env is nil (status unknown)' do
        handler.call('frame', 5, nil)

        expect(on_chunk_calls).to eq([['frame', nil]])
        expect(on_failed_calls).to be_empty
      end

      it 'routes the chunk to on_chunk when env reports a 200 status' do
        env = Struct.new(:status).new(200)
        handler.call('frame', 5, env)

        expect(on_chunk_calls).to eq([['frame', env]])
        expect(on_failed_calls).to be_empty
      end

      it 'routes the chunk to on_failed_response when env reports a non-200 status' do
        env = Struct.new(:status).new(403)
        handler.call('error-frame', 11, env)

        expect(on_failed_calls).to eq([['error-frame', env]])
        expect(on_chunk_calls).to be_empty
      end
    end
  end
end
