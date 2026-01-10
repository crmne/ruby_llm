# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK do
  describe 'VERSION' do
    it 'is defined' do
      expect(described_class::VERSION).to be_a(String)
      expect(described_class::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe '.tool' do
    it 'creates a Tool instance' do
      tool = described_class.tool(
        name: 'test',
        description: 'A test tool',
        input_schema: {}
      ) { 'result' }

      expect(tool).to be_a(RubyLLM::AgentSDK::Tool)
      expect(tool.name).to eq('test')
      expect(tool.description).to eq('A test tool')
    end
  end

  describe '.mcp_server' do
    it 'creates an MCP::Server instance' do
      server = described_class.mcp_server(
        'test',
        transport: :http,
        url: 'http://localhost:8080'
      )

      expect(server).to be_a(RubyLLM::AgentSDK::MCP::Server)
      expect(server.name).to eq('test')
      expect(server.transport).to eq(:http)
    end
  end

  describe '.options' do
    it 'returns an Options builder' do
      opts = described_class.options
      expect(opts).to be_a(RubyLLM::AgentSDK::Options)
    end

    it 'supports fluent interface' do
      opts = described_class.options
        .with_tools(:Read, :Edit)
        .with_model(:sonnet)

      expect(opts.allowed_tools).to eq(%w[Read Edit])
      expect(opts.model).to eq(:sonnet)
    end
  end

  describe '.schema' do
    it 'returns SDK introspection schema' do
      schema = described_class.schema
      expect(schema).to be_a(Hash)
      expect(schema).to have_key(:version)
      expect(schema).to have_key(:options)
      expect(schema).to have_key(:hooks)
    end
  end

  describe '.capabilities_prompt' do
    it 'returns markdown capabilities description' do
      prompt = described_class.capabilities_prompt
      expect(prompt).to be_a(String)
      expect(prompt).to include('Agent SDK Capabilities')
    end
  end

  describe '.supports?' do
    it 'delegates to Introspection' do
      expect(described_class.supports?(:streaming)).to be true
      expect(described_class.supports?(:unknown)).to be false
    end
  end

  describe '.validate_config' do
    it 'validates configuration hash' do
      errors = described_class.validate_config({ permission_mode: :invalid })
      expect(errors).not_to be_empty
    end
  end

  describe '.client' do
    it 'creates a Client instance' do
      client = described_class.client(permission_mode: :accept_edits)
      expect(client).to be_a(RubyLLM::AgentSDK::Client)
    end
  end
end
