# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'
require_relative 'support/mock_cli'

RSpec.describe 'RubyLLM::AgentSDK Integration', :integration do
  let(:mock_cli) { nil }

  after do
    mock_cli&.cleanup
  end

  describe 'simple query' do
    let(:mock_cli) do
      RubyLLM::AgentSDK::Testing::MockCLI.simple_response(
        "Hello! I'm Claude, an AI assistant. How can I help you today?"
      )
    end

    it 'streams messages from CLI' do
      cli_path = mock_cli.create_script
      messages = []

      RubyLLM::AgentSDK.query(
        "Say hello",
        cli_path: cli_path
      ) do |message|
        messages << message
      end

      expect(messages.size).to be >= 2

      # Should have init message
      init_msg = messages.find(&:init?)
      expect(init_msg).not_to be_nil
      expect(init_msg.tools).to include('Bash', 'Read')

      # Should have result message
      result_msg = messages.find(&:result?)
      expect(result_msg).not_to be_nil
      expect(result_msg.success?).to be true
      expect(result_msg.num_turns).to eq(1)
    end
  end

  describe 'query with tool usage' do
    let(:mock_cli) do
      RubyLLM::AgentSDK::Testing::MockCLI.with_tool_use(
        "I found 3 Ruby files in the directory.",
        tool_name: 'Bash',
        tool_input: { command: 'ls *.rb' },
        tool_result: "file1.rb\nfile2.rb\nfile3.rb"
      )
    end

    it 'captures tool use and results' do
      cli_path = mock_cli.create_script
      messages = []

      RubyLLM::AgentSDK.query(
        "List Ruby files",
        cli_path: cli_path
      ) do |message|
        messages << message
      end

      # Should have assistant messages
      assistant_msgs = messages.select(&:assistant?)
      expect(assistant_msgs).not_to be_empty
    end
  end

  describe 'error handling' do
    let(:mock_cli) do
      RubyLLM::AgentSDK::Testing::MockCLI.error_response('error_max_turns')
    end

    it 'reports error subtype' do
      cli_path = mock_cli.create_script
      result_msg = nil

      RubyLLM::AgentSDK.query(
        "Complex task",
        cli_path: cli_path
      ) do |message|
        result_msg = message if message.result?
      end

      expect(result_msg).not_to be_nil
      expect(result_msg.error?).to be true
      expect(result_msg.error_max_turns?).to be true
    end
  end

  describe 'with hooks' do
    let(:mock_cli) do
      RubyLLM::AgentSDK::Testing::MockCLI.with_tool_use(
        "Done listing files.",
        tool_name: 'Bash',
        tool_input: { command: 'ls' },
        tool_result: "file.txt"
      )
    end

    it 'executes pre_tool_use hooks during streaming' do
      cli_path = mock_cli.create_script
      hook_calls = []

      hooks = {
        pre_tool_use: [
          {
            handler: lambda do |ctx|
              hook_calls << { event: :pre_tool_use, tool: ctx.tool_name, input: ctx.tool_input }
              RubyLLM::AgentSDK::Hooks::Result.approve
            end
          }
        ]
      }

      messages = []
      RubyLLM::AgentSDK.query(
        "List files",
        cli_path: cli_path,
        hooks: hooks
      ) do |message|
        messages << message
      end

      # Hooks should have been called for tool use
      expect(hook_calls.size).to be >= 1
      expect(hook_calls.first[:tool]).to eq('Bash')
    end

    it 'executes session lifecycle hooks' do
      cli_path = mock_cli.create_script
      lifecycle_events = []

      hooks = {
        session_start: [
          {
            handler: lambda do |ctx|
              lifecycle_events << { event: :session_start, source: ctx.metadata[:source] }
              RubyLLM::AgentSDK::Hooks::Result.approve
            end
          }
        ],
        session_end: [
          {
            handler: lambda do |ctx|
              lifecycle_events << { event: :session_end, reason: ctx.metadata[:reason] }
              RubyLLM::AgentSDK::Hooks::Result.approve
            end
          }
        ]
      }

      RubyLLM::AgentSDK.query(
        "Hello",
        cli_path: cli_path,
        hooks: hooks
      ) do |_message|
        # Just consume messages
      end

      expect(lifecycle_events.size).to eq(2)
      expect(lifecycle_events.first[:event]).to eq(:session_start)
      expect(lifecycle_events.last[:event]).to eq(:session_end)
    end

    it 'blocks tool use messages when hook returns blocked' do
      cli_path = mock_cli.create_script

      hooks = {
        pre_tool_use: [
          {
            handler: lambda do |_ctx|
              RubyLLM::AgentSDK::Hooks::Result.block('Bash commands blocked')
            end
          }
        ]
      }

      messages = []
      RubyLLM::AgentSDK.query(
        "List files",
        cli_path: cli_path,
        hooks: hooks
      ) do |message|
        messages << message
      end

      # Tool use message should be filtered out (not yielded)
      tool_use_msgs = messages.select(&:tool_use?)
      expect(tool_use_msgs).to be_empty
    end
  end

  describe 'with options' do
    let(:mock_cli) do
      RubyLLM::AgentSDK::Testing::MockCLI.simple_response("Response with options")
    end

    it 'builds correct CLI arguments' do
      options = RubyLLM::AgentSDK::Options.build
        .with_max_turns(5)
        .with_model('claude-sonnet')
        .with_cwd('/tmp')
        .with_fallback_model('claude-haiku')
        .with_max_budget_usd(1.0)

      args = options.to_cli_args

      expect(args[:max_turns]).to eq(5)
      expect(args[:model]).to eq('claude-sonnet')
      expect(args[:cwd]).to eq('/tmp')
      expect(args[:fallback_model]).to eq('claude-haiku')
      expect(args[:max_budget_usd]).to eq(1.0)
    end
  end

  describe 'session management' do
    it 'creates unique session IDs' do
      session1 = RubyLLM::AgentSDK::Session.new
      session2 = RubyLLM::AgentSDK::Session.new

      expect(session1.id).not_to eq(session2.id)
    end

    it 'supports session forking' do
      original = RubyLLM::AgentSDK::Session.new
      original.add_message(RubyLLM::AgentSDK::Message.new(type: 'user', content: 'Hello'))

      forked = original.fork

      expect(forked.parent_id).to eq(original.id)
      expect(forked.forked?).to be true
      expect(forked.messages.size).to eq(1)

      # Forked session should have independent messages
      forked.add_message(RubyLLM::AgentSDK::Message.new(type: 'user', content: 'World'))
      expect(forked.messages.size).to eq(2)
      expect(original.messages.size).to eq(1)
    end

    it 'supports session resume' do
      original_id = 'session-abc-123'
      resumed = RubyLLM::AgentSDK::Session.resume(original_id)

      expect(resumed.id).to eq(original_id)
    end
  end

  describe 'message parsing' do
    it 'parses init message correctly' do
      json = {
        type: 'system',
        subtype: 'init',
        session_id: 'sess-123',
        cwd: '/home/user',
        model: 'claude-sonnet',
        tools: %w[Bash Read],
        permissionMode: 'default'
      }

      msg = RubyLLM::AgentSDK::Message.new(json)

      expect(msg.init?).to be true
      expect(msg.cwd).to eq('/home/user')
      expect(msg.model).to eq('claude-sonnet')
      expect(msg.tools).to eq(%w[Bash Read])
    end

    it 'parses result message correctly' do
      json = {
        type: 'result',
        subtype: 'success',
        session_id: 'sess-123',
        duration_ms: 1500,
        num_turns: 3,
        total_cost_usd: 0.05
      }

      msg = RubyLLM::AgentSDK::Message.new(json)

      expect(msg.result?).to be true
      expect(msg.success?).to be true
      expect(msg.duration_ms).to eq(1500)
      expect(msg.num_turns).to eq(3)
      expect(msg.total_cost_usd).to eq(0.05)
    end

    it 'parses assistant message with content blocks' do
      json = {
        type: 'assistant',
        message: {
          role: 'assistant',
          content: [
            { type: 'text', text: 'Hello ' },
            { type: 'text', text: 'World' }
          ]
        }
      }

      msg = RubyLLM::AgentSDK::Message.new(json)

      expect(msg.assistant?).to be true
      expect(msg.content).to eq("Hello \nWorld")
    end
  end
end

RSpec.describe 'RubyLLM::AgentSDK::Client Integration', :integration do
  let(:mock_cli) do
    RubyLLM::AgentSDK::Testing::MockCLI.simple_response("Hello from client!")
  end

  after do
    mock_cli&.cleanup
  end

  it 'returns lazy enumerator for streaming' do
    cli_path = mock_cli.create_script

    client = RubyLLM::AgentSDK::Client.new(cli_path: cli_path)
    result = client.query("Hello")

    expect(result).to be_a(Enumerator::Lazy)
  end

  it 'captures session_id from result message' do
    cli_path = mock_cli.create_script

    client = RubyLLM::AgentSDK::Client.new(cli_path: cli_path)

    # Consume the enumerator to trigger session_id capture
    client.query("Hello").each { |_msg| }

    expect(client.session_id).to eq('test-session-123')
  end

  it 'exposes capabilities' do
    client = RubyLLM::AgentSDK::Client.new(
      model: 'claude-sonnet',
      max_turns: 10,
      permission_mode: :accept_edits
    )

    caps = client.capabilities

    expect(caps[:model]).to eq('claude-sonnet')
    expect(caps[:max_turns]).to eq(10)
    expect(caps[:permission_mode]).to eq(:accept_edits)
  end

  describe 'with hooks' do
    let(:mock_cli) do
      RubyLLM::AgentSDK::Testing::MockCLI.with_tool_use(
        "Done reading file.",
        tool_name: 'Read',
        tool_input: { file_path: '/tmp/test.txt' },
        tool_result: "file contents"
      )
    end

    it 'executes hooks via with_hooks fluent method' do
      cli_path = mock_cli.create_script
      hook_calls = []

      client = RubyLLM::AgentSDK::Client.new(cli_path: cli_path)
        .with_hooks({
          pre_tool_use: [
            {
              handler: lambda do |ctx|
                hook_calls << { tool: ctx.tool_name }
                RubyLLM::AgentSDK::Hooks::Result.approve
              end
            }
          ]
        })

      client.query("Read file").each { |_| }

      expect(hook_calls.size).to be >= 1
      expect(hook_calls.first[:tool]).to eq('Read')
    end

    it 'fires session_start with resume source on subsequent queries' do
      cli_path = mock_cli.create_script
      sources = []

      hooks = {
        session_start: [
          {
            handler: lambda do |ctx|
              sources << ctx.metadata[:source]
              RubyLLM::AgentSDK::Hooks::Result.approve
            end
          }
        ]
      }

      client = RubyLLM::AgentSDK::Client.new(cli_path: cli_path, hooks: hooks)

      # First query - should be 'startup'
      client.query("First").each { |_| }

      # Second query - should be 'resume' (session_id captured)
      # Need a fresh mock CLI for the second query
      mock_cli2 = RubyLLM::AgentSDK::Testing::MockCLI.simple_response("Second response")
      cli_path2 = mock_cli2.create_script

      # Update client's cli_path for second query (via options)
      client.instance_variable_get(:@options).cli_path = cli_path2
      client.query("Second").each { |_| }

      mock_cli2.cleanup

      expect(sources.first).to eq('startup')
      expect(sources.last).to eq('resume')
    end
  end
end

RSpec.describe 'RubyLLM::AgentSDK::Stream', :integration do
  it 'parses JSON lines correctly' do
    json_line = '{"type":"system","subtype":"init","session_id":"test"}'
    msg = RubyLLM::AgentSDK::Stream.parse(json_line)

    expect(msg).to be_a(RubyLLM::AgentSDK::Message)
    expect(msg.init?).to be true
  end

  it 'raises JSONDecodeError for malformed JSON' do
    bad_line = 'not valid json'

    expect { RubyLLM::AgentSDK::Stream.parse(bad_line) }
      .to raise_error(RubyLLM::AgentSDK::JSONDecodeError)
  end

  it 'returns nil for empty and whitespace lines' do
    expect(RubyLLM::AgentSDK::Stream.parse('')).to be_nil
    expect(RubyLLM::AgentSDK::Stream.parse(nil)).to be_nil
    expect(RubyLLM::AgentSDK::Stream.parse('   ')).to be_nil
    expect(RubyLLM::AgentSDK::Stream.parse("\n")).to be_nil
  end
end

RSpec.describe 'RubyLLM::AgentSDK::Testing::CLICassette', :integration do
  let(:cassette_name) { "test_cassette_#{SecureRandom.hex(4)}" }
  let(:cassette) { RubyLLM::AgentSDK::Testing::CLICassette.new(cassette_name) }

  after do
    # Clean up test cassette
    File.delete(cassette.cassette_path) if File.exist?(cassette.cassette_path)
  end

  describe '#cassette_exists?' do
    it 'returns false when cassette does not exist' do
      expect(cassette.cassette_exists?).to be false
    end

    it 'returns true when cassette exists' do
      cassette.record!
      cassette.add_message({ type: 'test' })
      cassette.save

      expect(cassette.cassette_exists?).to be true
    end
  end

  describe '#record! and #save' do
    it 'records messages and saves to disk' do
      cassette.record!
      cassette.add_message({ type: 'system', subtype: 'init' })
      cassette.add_message({ type: 'result', subtype: 'success' })
      cassette.save

      expect(File.exist?(cassette.cassette_path)).to be true

      content = JSON.parse(File.read(cassette.cassette_path), symbolize_names: true)
      expect(content[:messages].size).to eq(2)
      expect(content[:metadata]).to include(:recorded_at)
    end

    it 'does not record when not in recording mode' do
      cassette.add_message({ type: 'test' })
      expect(cassette.messages).to be_empty
    end
  end

  describe '#load' do
    it 'loads saved cassette' do
      cassette.record!
      cassette.add_message({ type: 'system', subtype: 'init', session_id: 'test' })
      cassette.save

      new_cassette = RubyLLM::AgentSDK::Testing::CLICassette.new(cassette_name)
      expect(new_cassette.load).to be true
      expect(new_cassette.messages.size).to eq(1)
      expect(new_cassette.messages.first[:type]).to eq('system')
    end

    it 'returns false when cassette does not exist' do
      expect(cassette.load).to be false
    end
  end

  describe '#to_mock_cli' do
    it 'converts cassette to MockCLI' do
      cassette.record!
      cassette.add_message(RubyLLM::AgentSDK::Testing::MockCLI.init_message(session_id: 'test'))
      cassette.add_message(RubyLLM::AgentSDK::Testing::MockCLI.result_message(session_id: 'test'))
      cassette.save

      new_cassette = RubyLLM::AgentSDK::Testing::CLICassette.new(cassette_name)
      new_cassette.load

      mock_cli = new_cassette.to_mock_cli
      expect(mock_cli).to be_a(RubyLLM::AgentSDK::Testing::MockCLI)
      expect(mock_cli.messages.size).to eq(2)
    end
  end

  describe '#use_cassette' do
    it 'raises error when cassette not found and record: :none' do
      expect do
        cassette.use_cassette(record: :none) { |_| }
      end.to raise_error(RubyLLM::AgentSDK::Testing::CassetteNotFoundError)
    end

    it 'plays back existing cassette' do
      # First, create the cassette manually
      cassette.record!
      cassette.add_message(RubyLLM::AgentSDK::Testing::MockCLI.init_message(session_id: 'playback-test'))
      cassette.add_message(RubyLLM::AgentSDK::Testing::MockCLI.assistant_message('Playback test!'))
      cassette.add_message(RubyLLM::AgentSDK::Testing::MockCLI.result_message(session_id: 'playback-test'))
      cassette.save

      # Now use it for playback
      messages = []
      cassette.use_cassette(record: :none) do |cli_path|
        RubyLLM::AgentSDK.query('Test', cli_path: cli_path) do |message|
          messages << message
        end
      end

      expect(messages.size).to eq(3)
      expect(messages.find(&:init?)).not_to be_nil
      expect(messages.find(&:result?)).not_to be_nil
    end
  end
end

RSpec.describe 'RubyLLM::AgentSDK::Testing::RSpecHelpers', :integration do
  describe '#with_simple_response' do
    it 'provides mock CLI with simple response' do
      messages = []

      with_simple_response('Test response!') do |cli_path|
        RubyLLM::AgentSDK.query('Hello', cli_path: cli_path) do |message|
          messages << message
        end
      end

      expect(messages).not_to be_empty
      assistant_msg = messages.find(&:assistant?)
      expect(assistant_msg).not_to be_nil
      expect(assistant_msg.content).to include('Test response!')
    end
  end

  describe '#with_mock_cli' do
    it 'allows custom message sequences' do
      custom_messages = [
        { type: 'system', subtype: 'init', session_id: 'custom', tools: ['Bash'] },
        { type: 'assistant', message: { role: 'assistant', content: [{ type: 'text', text: 'Custom!' }] } },
        { type: 'result', subtype: 'success', session_id: 'custom', num_turns: 1 }
      ]

      messages = []
      with_mock_cli(custom_messages) do |cli_path|
        RubyLLM::AgentSDK.query('Test', cli_path: cli_path) do |message|
          messages << message
        end
      end

      expect(messages.size).to eq(3)
      init_msg = messages.find(&:init?)
      expect(init_msg.tools).to eq(['Bash'])
    end
  end
end
