# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Batches do
  let(:protocol) { RubyLLM::Providers::Anthropic.protocols.fetch(:anthropic).allocate }

  describe '#parse_batch_response' do
    it 'normalizes the batch attributes' do
      data = {
        'id' => 'msgbatch_123',
        'processing_status' => 'in_progress',
        'request_counts' => { 'processing' => 2, 'succeeded' => 0 }
      }

      attributes = protocol.send(:parse_batch_response, data)

      expect(attributes).to eq(
        id: 'msgbatch_123',
        raw_status: 'in_progress',
        completed: false,
        request_counts: { 'processing' => 2, 'succeeded' => 0 },
        request_count: 2
      )
    end

    it 'marks ended batches completed' do
      attributes = protocol.send(:parse_batch_response, 'id' => 'msgbatch_123', 'processing_status' => 'ended')

      expect(attributes).to include(completed: true)
    end

    it 'names how an ended batch finished from its request counts' do
      counts = { 'processing' => 0, 'succeeded' => 0, 'errored' => 1, 'canceled' => 0, 'expired' => 0 }
      statuses = [counts, counts.merge('canceled' => 2), counts.merge('expired' => 2)].map do |request_counts|
        protocol.send(:parse_batch_response, 'id' => 'msgbatch_123', 'processing_status' => 'ended',
                                             'request_counts' => request_counts)[:raw_status]
      end

      expect(statuses).to eq(%w[ended canceled expired])
    end

    it 'keeps a batch that ended with successes succeeded when some requests were cancelled' do
      counts = { 'processing' => 0, 'succeeded' => 3, 'errored' => 0, 'canceled' => 1, 'expired' => 1 }
      raw_status = protocol.send(:parse_batch_response, 'id' => 'msgbatch_123', 'processing_status' => 'ended',
                                                        'request_counts' => counts)[:raw_status]

      expect(protocol.send(:parse_batch_status, raw_status, completed: true)).to eq(:succeeded)
    end
  end

  describe '#create_batch' do
    it 'submits each request under its custom_id with its payload as params' do
      connection = instance_double(RubyLLM::Transport::Connection)
      protocol.instance_variable_set(:@connection, connection)
      allow(connection).to receive(:post).and_return(
        instance_double(Faraday::Response, body: { 'id' => 'msgbatch_1', 'processing_status' => 'in_progress' })
      )

      protocol.create_batch([{ custom_id: '0', payload: { model: 'claude-haiku-4-5' } }])

      expect(connection).to have_received(:post).with(
        'v1/messages/batches', { requests: [{ custom_id: '0', params: { model: 'claude-haiku-4-5' } }] },
        idempotent: false
      )
    end
  end

  describe '#parse_batch_status' do
    it 'succeeds only an ended batch that completed' do
      statuses = [['ended', true], ['ended', false], ['canceling', true]].map do |raw_status, completed|
        protocol.send(:parse_batch_status, raw_status, completed:)
      end

      expect(statuses).to eq(%i[succeeded pending pending])
    end

    it 'tells a cancelled or expired batch from one that succeeded' do
      statuses = %w[canceled expired].map do |raw_status|
        protocol.send(:parse_batch_status, raw_status, completed: true)
      end

      expect(statuses).to eq(%i[cancelled failed])
    end
  end

  describe '#parse_batch_result' do
    it 'parses succeeded results into messages keyed by submission index' do
      line = {
        'custom_id' => '1',
        'result' => {
          'type' => 'succeeded',
          'message' => {
            'content' => [{ 'type' => 'text', 'text' => 'Jupiter' }],
            'model' => 'claude-haiku-4-5',
            'usage' => { 'input_tokens' => 10, 'output_tokens' => 2 }
          }
        }
      }

      index, message = protocol.send(:parse_batch_result, line)

      expect(index).to eq(1)
      expect(message.content).to eq('Jupiter')
      expect(message.model).to eq('claude-haiku-4-5')
      expect(message.tokens.input).to eq(10)
    end

    it 'logs and skips failed results' do
      line = {
        'custom_id' => '0',
        'result' => {
          'type' => 'errored',
          'error' => { 'type' => 'error', 'error' => { 'type' => 'invalid_request_error', 'message' => 'too long' } }
        }
      }
      allow(RubyLLM.logger).to receive(:warn)

      index, message, status = protocol.send(:parse_batch_result, line)

      expect(index).to eq(0)
      expect(message).to be_nil
      expect(status).to eq(:failed)
      expect(RubyLLM.logger).to have_received(:warn).with(/errored: too long/)
    end

    it 'normalizes canceled request results' do
      line = {
        'custom_id' => '0',
        'result' => { 'type' => 'canceled' }
      }
      allow(RubyLLM.logger).to receive(:warn)

      _index, _message, status = protocol.send(:parse_batch_result, line)

      expect(status).to eq(:cancelled)
    end
  end

  describe 'beta headers' do
    include_context 'with configured RubyLLM'

    let(:provider) { RubyLLM::Providers::Anthropic.new(RubyLLM.config) }
    let(:live) { RubyLLM::Providers::Anthropic.protocols.fetch(:anthropic).new(provider) }
    let(:file_block) { { type: 'document', source: { type: 'file', file_id: 'f' } } }
    let(:file_payload) { { messages: [{ role: 'user', content: [file_block] }] } }

    it 'sends every beta any batch entry needs' do
      request = stub_request(:post, 'https://api.anthropic.com/v1/messages/batches')
                .with(headers: { 'anthropic-beta' => 'files-api-2025-04-14,compact-2026-01-12' })
                .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                           body: { id: 'b', processing_status: 'in_progress' }.to_json)

      live.create_batch([{ custom_id: '0', payload: file_payload },
                         { custom_id: '1', payload: { messages: [], context_management: { edits: [] } } }])

      expect(request).to have_been_requested
    end

    it 'sends the MCP beta when an entry connects a server' do
      request = stub_request(:post, 'https://api.anthropic.com/v1/messages/batches')
                .with(headers: { 'anthropic-beta' => 'mcp-client-2025-11-20' })
                .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                           body: { id: 'b', processing_status: 'in_progress' }.to_json)

      live.create_batch([{ custom_id: '0', payload: { messages: [], mcp_servers: [{ name: 'docs' }] } }])

      expect(request).to have_been_requested
    end

    it 'reads provider options under string keys' do
      betas = nil
      request = stub_request(:post, 'https://api.anthropic.com/v1/messages/batches')
                .with { |sent| betas = sent.headers['Anthropic-Beta'] }
                .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                           body: { id: 'b', processing_status: 'in_progress' }.to_json)
      payload = { messages: [], 'mcp_servers' => [{ name: 'docs' }], 'context_management' => { edits: [] } }

      live.create_batch([{ custom_id: '0', payload: }])

      expect(request).to have_been_requested
      expect(betas).to include('mcp-client-2025-11-20', 'compact-2026-01-12')
    end

    it 'sends the betas each chat set with with_headers, whatever their spelling' do
      betas = nil
      request = stub_request(:post, 'https://api.anthropic.com/v1/messages/batches')
                .with { |sent| betas = sent.headers['Anthropic-Beta'] }
                .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                           body: { id: 'b', processing_status: 'in_progress' }.to_json)

      live.create_batch([
                          { custom_id: '0', payload: { messages: [] }, headers: { 'anthropic-beta' => 'one,two' } },
                          { custom_id: '1', payload: { messages: [] }, headers: { 'Anthropic-Beta' => 'two,three' } },
                          { custom_id: '2', payload: { messages: [] }, headers: { 'x-other' => '1' } }
                        ])

      expect(request).to have_been_requested
      expect(betas).to eq('one,two,three')
    end

    it 'carries a chat beta from with_headers into the batch request' do
      request = stub_request(:post, 'https://api.anthropic.com/v1/messages/batches')
                .with(headers: { 'anthropic-beta' => 'mine' })
                .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                           body: { id: 'b', processing_status: 'in_progress' }.to_json)
      chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)
                    .with_headers('Anthropic-Beta' => 'mine').ask_later('Hi')

      RubyLLM.batch(chat)

      expect(request).to have_been_requested
    end

    it 'sends no beta a plain batch does not need' do
      request = stub_request(:post, 'https://api.anthropic.com/v1/messages/batches')
                .with { |sent| !sent.headers.key?('Anthropic-Beta') }
                .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                           body: { id: 'b', processing_status: 'in_progress' }.to_json)

      live.create_batch([{ custom_id: '0', payload: { messages: [] } }])

      expect(request).to have_been_requested
    end

    it 'sends the Files beta when counting tokens over an uploaded file' do
      request = stub_request(:post, 'https://api.anthropic.com/v1/messages/count_tokens')
                .with(headers: { 'anthropic-beta' => 'files-api-2025-04-14' })
                .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                           body: { input_tokens: 5 }.to_json)

      live.send(:post_count_tokens, file_payload)

      expect(request).to have_been_requested
    end

    it 'joins a beta from with_headers whatever its capitalization' do
      merged = live.send(:merge_tool_headers, { 'anthropic-beta' => 'mcp' }, { 'Anthropic-Beta' => 'mine' })

      expect(merged).to eq('anthropic-beta' => 'mcp,mine')
    end

    it 'keeps a capitalized with_headers beta when compaction adds its own' do
      headers = live.send(:apply_compaction_headers, { 'Anthropic-Beta' => 'mine', 'x-mine' => '1' }, {})

      expect(headers).to eq('anthropic-beta' => 'mine,compact-2026-01-12', 'x-mine' => '1')
    end

    it 'keeps a capitalized with_headers beta when a file adds its own' do
      headers = live.send(:beta_headers, { 'Anthropic-Beta' => 'mine' }, file_payload)

      expect(headers).to eq('anthropic-beta' => 'mine,files-api-2025-04-14')
    end

    it 'folds every spelling of the beta header into one' do
      headers = live.send(:beta_headers, { 'Anthropic-Beta' => 'a,b', :'anthropic-BETA' => 'b,c' }, {})

      expect(headers).to eq('anthropic-beta' => 'a,b,c')
    end

    it 'leaves headers without a beta alone' do
      expect(live.send(:beta_headers, { 'x-mine' => '1' }, {})).to eq('x-mine' => '1')
    end

    it 'finds a file in a block with string keys' do
      block = { 'type' => 'tool_result', 'content' => [{ 'source' => { 'type' => 'file', 'file_id' => 'f' } }] }

      expect(live.send(:provider_file_source?, { messages: [{ 'content' => [block] }] })).to be(true)
    end

    it 'joins a beta from with_headers with the one a server tool needs' do
      merged = live.send(:merge_tool_headers, { 'anthropic-beta' => 'mcp', 'x-tool' => '1' },
                         { 'anthropic-beta' => 'mine', 'x-mine' => '2' })

      expect(merged).to eq('anthropic-beta' => 'mcp,mine', 'x-tool' => '1', 'x-mine' => '2')
    end

    it 'keeps tool headers when with_headers set no beta' do
      expect(live.send(:merge_tool_headers, { 'anthropic-beta' => 'mcp' }, {})).to eq('anthropic-beta' => 'mcp')
    end
  end
end
