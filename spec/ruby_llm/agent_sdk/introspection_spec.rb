# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Introspection do
  describe 'constants' do
    it 'lists built-in tools' do
      expect(described_class::BUILT_IN_TOOLS).to include(
        'Bash', 'Read', 'Write', 'Edit', 'Glob', 'Grep', 'Task', 'WebFetch', 'WebSearch'
      )
    end

    it 'lists available models' do
      expect(described_class::MODELS).to eq(%i[opus sonnet haiku])
    end

    it 'lists hook events with descriptions' do
      expect(described_class::HOOK_EVENTS).to have_key(:pre_tool_use)
      expect(described_class::HOOK_EVENTS[:pre_tool_use]).to be_a(String)
    end

    it 'lists permission modes with descriptions' do
      expect(described_class::PERMISSION_MODES).to have_key(:default)
      expect(described_class::PERMISSION_MODES).to have_key(:bypass_permissions)
    end
  end

  describe '.schema' do
    let(:schema) { described_class.schema }

    it 'includes version' do
      expect(schema[:version]).to eq(RubyLLM::AgentSDK::VERSION)
    end

    it 'includes options schema' do
      expect(schema[:options]).to be_a(Hash)
      expect(schema[:options]).to have_key(:permission_mode)
    end

    it 'includes hooks schema' do
      expect(schema[:hooks]).to have_key(:events)
      expect(schema[:hooks]).to have_key(:decisions)
    end

    it 'includes permissions schema' do
      expect(schema[:permissions]).to have_key(:modes)
    end

    it 'includes tools schema' do
      expect(schema[:tools]).to have_key(:built_in)
    end

    it 'includes models' do
      expect(schema[:models]).to eq(%i[opus sonnet haiku])
    end

    it 'includes MCP transports' do
      expect(schema[:mcp_transports]).to include(:stdio, :sse, :http, :sdk)
    end
  end

  describe '.options_schema' do
    it 'returns Options schema' do
      expect(described_class.options_schema).to eq(RubyLLM::AgentSDK::Options::SCHEMA)
    end
  end

  describe '.hooks_schema' do
    let(:schema) { described_class.hooks_schema }

    it 'includes events' do
      expect(schema[:events]).to eq(described_class::HOOK_EVENTS)
    end

    it 'includes decisions' do
      expect(schema[:decisions]).to eq(RubyLLM::AgentSDK::Hooks::DECISIONS)
    end
  end

  describe '.permissions_schema' do
    let(:schema) { described_class.permissions_schema }

    it 'includes modes' do
      expect(schema[:modes]).to eq(described_class::PERMISSION_MODES)
    end

    it 'includes accept_edits_tools' do
      expect(schema[:accept_edits_tools]).to include('Edit', 'Write')
    end
  end

  describe '.tools_schema' do
    let(:schema) { described_class.tools_schema }

    it 'includes built-in tools' do
      expect(schema[:built_in]).to eq(described_class::BUILT_IN_TOOLS)
    end

    it 'includes custom schema definition' do
      expect(schema[:custom_schema]).to have_key(:name)
      expect(schema[:custom_schema]).to have_key(:description)
    end
  end

  describe '.generate_capabilities_prompt' do
    let(:prompt) { described_class.generate_capabilities_prompt }

    it 'includes section headers' do
      expect(prompt).to include('# Agent SDK Capabilities')
      expect(prompt).to include('## Configuration Options')
      expect(prompt).to include('## Permission Modes')
      expect(prompt).to include('## Available Hooks')
      expect(prompt).to include('## Built-in Tools')
    end

    it 'lists permission modes' do
      expect(prompt).to include('default')
      expect(prompt).to include('accept_edits')
      expect(prompt).to include('bypass_permissions')
    end

    it 'lists built-in tools' do
      expect(prompt).to include('Bash')
      expect(prompt).to include('Read')
      expect(prompt).to include('Edit')
    end

    it 'lists MCP transports' do
      expect(prompt).to include('stdio')
      expect(prompt).to include('sse')
    end
  end

  describe '.validate_config' do
    it 'returns empty array for valid config' do
      errors = described_class.validate_config({
        permission_mode: :accept_edits,
        model: :sonnet,
        max_turns: 10
      })
      expect(errors).to be_empty
    end

    it 'returns errors for unknown options' do
      errors = described_class.validate_config({ unknown_option: 'value' })
      expect(errors).to include(/Unknown option.*unknown_option/)
    end

    it 'returns errors for invalid permission mode' do
      errors = described_class.validate_config({ permission_mode: :invalid_mode })
      expect(errors).to include(/Invalid permission_mode/)
    end

    it 'returns errors for invalid model' do
      errors = described_class.validate_config({ model: :invalid_model })
      expect(errors).to include(/Invalid model/)
    end
  end

  describe '.supports?' do
    it 'returns true for supported capabilities' do
      %i[streaming hooks mcp custom_tools sessions multi_turn permission_modes subagents].each do |cap|
        expect(described_class.supports?(cap)).to be true
      end
    end

    it 'returns false for unknown capabilities' do
      expect(described_class.supports?(:teleportation)).to be false
    end
  end
end
