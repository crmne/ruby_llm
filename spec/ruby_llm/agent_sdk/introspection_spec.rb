# frozen_string_literal: true

RSpec.describe RubyLLM::AgentSDK::Introspection do
  describe 'BUILTIN_TOOLS' do
    it 'includes all 17 built-in tools' do
      expect(described_class::BUILTIN_TOOLS.size).to eq(17)
    end

    it 'includes essential tools' do
      essential_tools = %w[Read Write Edit Bash Glob Grep]
      essential_tools.each do |tool|
        expect(described_class::BUILTIN_TOOLS).to include(tool)
      end
    end

    it 'includes agent tools' do
      agent_tools = %w[Agent AskUserQuestion TodoWrite]
      agent_tools.each do |tool|
        expect(described_class::BUILTIN_TOOLS).to include(tool)
      end
    end

    it 'includes web tools' do
      web_tools = %w[WebFetch WebSearch]
      web_tools.each do |tool|
        expect(described_class::BUILTIN_TOOLS).to include(tool)
      end
    end

    it 'includes planning tools' do
      planning_tools = %w[ExitPlanMode EnterPlanMode]
      planning_tools.each do |tool|
        expect(described_class::BUILTIN_TOOLS).to include(tool)
      end
    end

    it 'is frozen' do
      expect(described_class::BUILTIN_TOOLS).to be_frozen
    end
  end

  describe '.cli_available?' do
    it 'returns boolean' do
      result = described_class.cli_available?
      expect([true, false]).to include(result)
    end
  end

  describe '.cli_version' do
    context 'when CLI is available' do
      before do
        allow(described_class).to receive(:`).with('claude --version 2>/dev/null').and_return("1.0.0\n")
      end

      it 'returns version string' do
        expect(described_class.cli_version).to eq('1.0.0')
      end
    end

    context 'when CLI is not available' do
      before do
        allow(described_class).to receive(:`).with('claude --version 2>/dev/null').and_return('')
      end

      it 'returns nil' do
        expect(described_class.cli_version).to be_nil
      end
    end

    context 'when command raises error' do
      before do
        allow(described_class).to receive(:`).and_raise(StandardError)
      end

      it 'returns nil' do
        expect(described_class.cli_version).to be_nil
      end
    end
  end

  describe '.requirements_met?' do
    it 'returns hash with all requirements' do
      result = described_class.requirements_met?

      expect(result).to be_a(Hash)
      expect(result).to have_key(:cli_available)
      expect(result).to have_key(:cli_version)
      expect(result).to have_key(:oj_available)
    end

    it 'checks CLI availability' do
      result = described_class.requirements_met?
      expect([true, false]).to include(result[:cli_available])
    end

    it 'checks Oj availability' do
      result = described_class.requirements_met?
      expect([true, false]).to include(result[:oj_available])
    end
  end

  describe '.builtin_tools' do
    it 'returns BUILTIN_TOOLS constant' do
      expect(described_class.builtin_tools).to eq(described_class::BUILTIN_TOOLS)
    end
  end

  describe '.hook_events' do
    it 'returns all hook events' do
      events = described_class.hook_events

      expect(events).to include(:pre_tool_use)
      expect(events).to include(:post_tool_use)
      expect(events).to include(:session_start)
      expect(events).to include(:session_end)
    end

    it 'delegates to Hooks::EVENTS' do
      expect(described_class.hook_events).to eq(RubyLLM::AgentSDK::Hooks::EVENTS)
    end
  end

  describe '.permission_modes' do
    it 'returns all permission modes' do
      modes = described_class.permission_modes

      expect(modes).to include(:default)
      expect(modes).to include(:accept_edits)
      expect(modes).to include(:bypass_permissions)
      expect(modes).to include(:plan)
    end

    it 'delegates to Permissions::MODES' do
      expect(described_class.permission_modes).to eq(RubyLLM::AgentSDK::Permissions::MODES)
    end
  end

  describe '.options_schema' do
    it 'returns options schema' do
      schema = described_class.options_schema

      expect(schema).to be_a(Hash)
      expect(schema).not_to be_empty
    end

    it 'delegates to Options::SCHEMA' do
      expect(described_class.options_schema).to eq(RubyLLM::AgentSDK::Options::SCHEMA)
    end
  end

  describe '.available_tools' do
    it 'returns builtin tools by default' do
      tools = described_class.available_tools
      expect(tools).to eq(described_class::BUILTIN_TOOLS)
    end

    it 'includes custom tools when provided' do
      custom_tool = RubyLLM::AgentSDK::Tool.new(
        name: 'my_custom_tool',
        description: 'Custom tool'
      ) {}

      tools = described_class.available_tools(custom_tools: [custom_tool])

      expect(tools).to include('Read')
      expect(tools).to include('my_custom_tool')
    end

    it 'handles string custom tools' do
      tools = described_class.available_tools(custom_tools: ['custom_a', 'custom_b'])

      expect(tools).to include('custom_a')
      expect(tools).to include('custom_b')
    end

    it 'handles mixed custom tools' do
      tool_object = RubyLLM::AgentSDK::Tool.new(name: 'tool_obj', description: 'Object') {}

      tools = described_class.available_tools(custom_tools: [tool_object, 'tool_str', :tool_sym])

      expect(tools).to include('tool_obj')
      expect(tools).to include('tool_str')
      expect(tools).to include('tool_sym')
    end
  end
end
