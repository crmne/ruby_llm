# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Message do
  describe 'TYPES' do
    it 'includes all SDK message types' do
      expect(described_class::TYPES).to eq([:assistant, :user, :result, :system, :stream_event])
    end
  end

  describe 'RESULT_SUBTYPES' do
    it 'includes all result subtypes' do
      expect(described_class::RESULT_SUBTYPES).to include(
        :success,
        :error_max_turns,
        :error_during_execution,
        :error_max_budget_usd,
        :error_max_structured_output_retries
      )
    end
  end

  describe 'SYSTEM_SUBTYPES' do
    it 'includes all system subtypes' do
      expect(described_class::SYSTEM_SUBTYPES).to eq([:init, :compact_boundary])
    end
  end

  describe '#initialize' do
    it 'parses type and subtype' do
      msg = described_class.new(type: 'result', subtype: 'success', uuid: 'abc-123')
      expect(msg.type).to eq(:result)
      expect(msg.subtype).to eq(:success)
      expect(msg.uuid).to eq('abc-123')
    end

    it 'infers type from role' do
      msg = described_class.new(role: 'assistant', content: 'Hello')
      expect(msg.type).to eq(:assistant)
    end
  end

  describe 'type predicates' do
    it 'assistant?' do
      msg = described_class.new(type: 'assistant')
      expect(msg.assistant?).to be true
      expect(msg.user?).to be false
    end

    it 'user?' do
      msg = described_class.new(type: 'user')
      expect(msg.user?).to be true
    end

    it 'result?' do
      msg = described_class.new(type: 'result', subtype: 'success')
      expect(msg.result?).to be true
    end

    it 'system?' do
      msg = described_class.new(type: 'system', subtype: 'init')
      expect(msg.system?).to be true
    end

    it 'stream_event? / partial?' do
      msg = described_class.new(type: 'stream_event')
      expect(msg.stream_event?).to be true
      expect(msg.partial?).to be true
    end
  end

  describe 'result subtype predicates' do
    it 'success?' do
      msg = described_class.new(type: 'result', subtype: 'success')
      expect(msg.success?).to be true
      expect(msg.error?).to be false
    end

    it 'error?' do
      msg = described_class.new(type: 'result', subtype: 'error_max_turns')
      expect(msg.error?).to be true
      expect(msg.success?).to be false
    end

    it 'error_max_turns?' do
      msg = described_class.new(type: 'result', subtype: 'error_max_turns')
      expect(msg.error_max_turns?).to be true
    end

    it 'error_during_execution?' do
      msg = described_class.new(type: 'result', subtype: 'error_during_execution')
      expect(msg.error_during_execution?).to be true
    end

    it 'error_max_budget?' do
      msg = described_class.new(type: 'result', subtype: 'error_max_budget_usd')
      expect(msg.error_max_budget?).to be true
    end
  end

  describe 'system subtype predicates' do
    it 'init?' do
      msg = described_class.new(type: 'system', subtype: 'init')
      expect(msg.init?).to be true
      expect(msg.compact_boundary?).to be false
    end

    it 'compact_boundary?' do
      msg = described_class.new(type: 'system', subtype: 'compact_boundary')
      expect(msg.compact_boundary?).to be true
      expect(msg.init?).to be false
    end
  end

  describe 'result message fields' do
    let(:result_msg) do
      described_class.new(
        type: 'result',
        subtype: 'success',
        uuid: 'result-123',
        session_id: 'sess-456',
        duration_ms: 1500,
        duration_api_ms: 1200,
        num_turns: 3,
        total_cost_usd: 0.05,
        usage: { input_tokens: 100, output_tokens: 200 },
        modelUsage: { 'claude-sonnet' => { inputTokens: 100 } },
        permission_denials: [],
        structured_output: { answer: 42 }
      )
    end

    it 'provides duration_ms' do
      expect(result_msg.duration_ms).to eq(1500)
    end

    it 'provides duration_api_ms' do
      expect(result_msg.duration_api_ms).to eq(1200)
    end

    it 'provides num_turns' do
      expect(result_msg.num_turns).to eq(3)
    end

    it 'provides total_cost_usd' do
      expect(result_msg.total_cost_usd).to eq(0.05)
    end

    it 'provides usage' do
      expect(result_msg.usage[:input_tokens]).to eq(100)
    end

    it 'provides model_usage' do
      expect(result_msg.model_usage).to be_a(Hash)
    end

    it 'provides structured_output' do
      expect(result_msg.structured_output[:answer]).to eq(42)
    end
  end

  describe 'system init message fields' do
    let(:init_msg) do
      described_class.new(
        type: 'system',
        subtype: 'init',
        apiKeySource: 'user',
        cwd: '/home/user',
        tools: ['Bash', 'Read'],
        mcp_servers: [{ name: 'filesystem', status: 'connected' }],
        model: 'claude-sonnet',
        permissionMode: 'default',
        slash_commands: ['/help', '/clear'],
        output_style: 'markdown'
      )
    end

    it 'provides api_key_source' do
      expect(init_msg.api_key_source).to eq('user')
    end

    it 'provides cwd' do
      expect(init_msg.cwd).to eq('/home/user')
    end

    it 'provides tools' do
      expect(init_msg.tools).to eq(['Bash', 'Read'])
    end

    it 'provides mcp_servers' do
      expect(init_msg.mcp_servers.first[:name]).to eq('filesystem')
    end

    it 'provides model' do
      expect(init_msg.model).to eq('claude-sonnet')
    end

    it 'provides permission_mode' do
      expect(init_msg.permission_mode).to eq('default')
    end

    it 'provides slash_commands' do
      expect(init_msg.slash_commands).to include('/help')
    end
  end

  describe 'compact boundary fields' do
    let(:compact_msg) do
      described_class.new(
        type: 'system',
        subtype: 'compact_boundary',
        compact_metadata: { trigger: 'auto', pre_tokens: 50000 }
      )
    end

    it 'provides compact_metadata' do
      expect(compact_msg.compact_metadata[:trigger]).to eq('auto')
      expect(compact_msg.compact_metadata[:pre_tokens]).to eq(50000)
    end
  end

  describe 'stream event fields' do
    let(:stream_msg) do
      described_class.new(
        type: 'stream_event',
        event: { type: 'content_block_delta', delta: { text: 'Hello' } },
        parent_tool_use_id: 'tool-123'
      )
    end

    it 'provides event' do
      expect(stream_msg.event[:type]).to eq('content_block_delta')
    end

    it 'provides parent_tool_use_id' do
      expect(stream_msg.parent_tool_use_id).to eq('tool-123')
    end
  end

  describe '#content' do
    it 'extracts text from content field' do
      msg = described_class.new(content: 'Hello world')
      expect(msg.content).to eq('Hello world')
    end

    it 'extracts text from message.content array' do
      msg = described_class.new(
        message: {
          content: [
            { type: 'text', text: 'Part 1' },
            { type: 'text', text: 'Part 2' }
          ]
        }
      )
      expect(msg.content).to eq("Part 1\nPart 2")
    end
  end

  describe '#to_h' do
    it 'returns original data' do
      data = { type: 'assistant', content: 'Hello' }
      msg = described_class.new(data)
      expect(msg.to_h).to eq(data)
    end
  end

  describe 'dynamic attribute access' do
    it 'allows accessing arbitrary fields' do
      msg = described_class.new(custom_field: 'value')
      expect(msg.custom_field).to eq('value')
    end
  end

  describe 'tool use detection' do
    describe '#tool_use?' do
      it 'returns false for non-assistant messages' do
        msg = described_class.new(type: 'user', content: 'Hello')
        expect(msg.tool_use?).to be false
      end

      it 'returns false for assistant messages without tool use' do
        msg = described_class.new(
          type: 'assistant',
          message: { content: [{ type: 'text', text: 'Hello' }] }
        )
        expect(msg.tool_use?).to be false
      end

      it 'returns true for assistant messages with tool_use content' do
        msg = described_class.new(
          type: 'assistant',
          message: {
            content: [
              { type: 'text', text: 'Let me check that' },
              { type: 'tool_use', id: 'tool-123', name: 'Bash', input: { command: 'ls' } }
            ]
          }
        )
        expect(msg.tool_use?).to be true
      end
    end

    describe '#tool_use_blocks' do
      it 'extracts tool use blocks from message content' do
        msg = described_class.new(
          type: 'assistant',
          message: {
            content: [
              { type: 'text', text: 'Let me check' },
              { type: 'tool_use', id: 'tool-123', name: 'Bash', input: { command: 'ls' } },
              { type: 'tool_use', id: 'tool-456', name: 'Read', input: { file_path: '/tmp/file' } }
            ]
          }
        )
        blocks = msg.tool_use_blocks
        expect(blocks.length).to eq(2)
        expect(blocks[0][:name]).to eq('Bash')
        expect(blocks[1][:name]).to eq('Read')
      end
    end

    describe '#tool_name' do
      it 'returns first tool name' do
        msg = described_class.new(
          type: 'assistant',
          message: {
            content: [
              { type: 'tool_use', id: 'tool-123', name: 'Bash', input: { command: 'ls' } }
            ]
          }
        )
        expect(msg.tool_name).to eq('Bash')
      end
    end

    describe '#tool_input' do
      it 'returns first tool input' do
        msg = described_class.new(
          type: 'assistant',
          message: {
            content: [
              { type: 'tool_use', id: 'tool-123', name: 'Bash', input: { command: 'ls -la' } }
            ]
          }
        )
        expect(msg.tool_input[:command]).to eq('ls -la')
      end
    end

    describe '#tool_use_id' do
      it 'returns first tool use ID' do
        msg = described_class.new(
          type: 'assistant',
          message: {
            content: [
              { type: 'tool_use', id: 'toolu_abc123', name: 'Bash', input: {} }
            ]
          }
        )
        expect(msg.tool_use_id).to eq('toolu_abc123')
      end
    end
  end
end

RSpec.describe RubyLLM::AgentSDK::PermissionDenial do
  it 'captures denied tool info' do
    denial = described_class.new(
      tool_name: 'Bash',
      tool_use_id: 'tool-123',
      tool_input: { command: 'rm -rf /' }
    )
    expect(denial.tool_name).to eq('Bash')
    expect(denial.tool_input[:command]).to eq('rm -rf /')
  end
end

RSpec.describe RubyLLM::AgentSDK::ModelUsage do
  it 'captures model usage stats' do
    usage = described_class.new(
      input_tokens: 100,
      output_tokens: 200,
      cache_read_input_tokens: 50,
      cost_usd: 0.05,
      context_window: 128_000
    )
    expect(usage.input_tokens).to eq(100)
    expect(usage.cost_usd).to eq(0.05)
  end
end

RSpec.describe RubyLLM::AgentSDK::Usage do
  it 'captures usage stats' do
    usage = described_class.new(
      input_tokens: 100,
      output_tokens: 200,
      cache_creation_input_tokens: 0,
      cache_read_input_tokens: 50
    )
    expect(usage.input_tokens).to eq(100)
    expect(usage.cache_read_input_tokens).to eq(50)
  end
end
