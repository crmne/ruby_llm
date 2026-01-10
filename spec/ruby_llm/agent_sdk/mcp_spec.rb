# frozen_string_literal: true

RSpec.describe RubyLLM::AgentSDK::MCP::Server do
  describe '#initialize' do
    it 'accepts type and config' do
      server = described_class.new(:stdio, command: 'npx', args: ['@playwright/mcp'])

      expect(server.type).to eq(:stdio)
      expect(server.config[:command]).to eq('npx')
      expect(server.config[:args]).to eq(['@playwright/mcp'])
    end

    it 'converts type to symbol' do
      server = described_class.new('stdio', command: 'test')
      expect(server.type).to eq(:stdio)
    end

    it 'freezes config' do
      server = described_class.new(:stdio, command: 'test')
      expect(server.config).to be_frozen
    end
  end

  describe '.stdio' do
    it 'creates stdio server with command and args' do
      server = described_class.stdio(
        command: 'npx',
        args: ['@playwright/mcp@latest'],
        env: { 'DEBUG' => 'true' }
      )

      expect(server.type).to eq(:stdio)
      expect(server.config[:command]).to eq('npx')
      expect(server.config[:args]).to eq(['@playwright/mcp@latest'])
      expect(server.config[:env]).to eq({ 'DEBUG' => 'true' })
    end

    it 'defaults args and env to empty' do
      server = described_class.stdio(command: 'my-server')

      expect(server.config[:args]).to eq([])
      expect(server.config[:env]).to eq({})
    end
  end

  describe '.ruby' do
    let(:mock_tool) do
      RubyLLM::AgentSDK::Tool.new(
        name: 'get_weather',
        description: 'Get weather',
        input_schema: { location: { type: 'string' } }
      ) { |args| "Weather for #{args[:location]}" }
    end

    it 'creates sdk server with tools' do
      server = described_class.ruby(tools: [mock_tool])

      expect(server.type).to eq(:sdk)
      expect(server.config[:tools]).to eq([mock_tool])
    end
  end

  describe '#to_cli_config' do
    context 'with stdio server' do
      it 'returns stdio CLI config' do
        server = described_class.stdio(
          command: 'npx',
          args: ['-y', '@modelcontextprotocol/server-github'],
          env: { 'GITHUB_TOKEN' => 'secret' }
        )

        config = server.to_cli_config

        expect(config).to eq(
          type: 'stdio',
          command: 'npx',
          args: ['-y', '@modelcontextprotocol/server-github'],
          env: { 'GITHUB_TOKEN' => 'secret' }
        )
      end
    end

    context 'with sdk server' do
      it 'returns sdk CLI config with tool schemas' do
        tool = RubyLLM::AgentSDK::Tool.new(
          name: 'search',
          description: 'Search items',
          input_schema: {
            type: 'object',
            properties: { query: { type: 'string' } },
            required: ['query']
          }
        ) {}

        server = described_class.ruby(tools: [tool])
        config = server.to_cli_config

        expect(config[:type]).to eq('sdk')
        expect(config[:tools]).to be_an(Array)
        expect(config[:tools].first[:name]).to eq('search')
        expect(config[:tools].first[:description]).to eq('Search items')
      end
    end

    context 'with unknown server type' do
      it 'returns generic config' do
        server = described_class.new(:custom, host: 'localhost', port: 8080)
        config = server.to_cli_config

        expect(config).to eq(
          type: 'custom',
          host: 'localhost',
          port: 8080
        )
      end
    end
  end

  describe 'real-world usage examples' do
    it 'can configure Playwright MCP server' do
      server = described_class.stdio(
        command: 'npx',
        args: ['@playwright/mcp@latest']
      )

      config = server.to_cli_config
      expect(config[:type]).to eq('stdio')
      expect(config[:command]).to eq('npx')
      expect(config[:args]).to include('@playwright/mcp@latest')
    end

    it 'can configure GitHub MCP server with token' do
      server = described_class.stdio(
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-github'],
        env: { 'GITHUB_TOKEN' => 'ghp_xxx' }
      )

      config = server.to_cli_config
      expect(config[:env]['GITHUB_TOKEN']).to eq('ghp_xxx')
    end

    it 'can configure SQLite MCP server' do
      server = described_class.stdio(
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-sqlite', 'db/development.sqlite3']
      )

      config = server.to_cli_config
      expect(config[:args]).to include('db/development.sqlite3')
    end
  end
end
