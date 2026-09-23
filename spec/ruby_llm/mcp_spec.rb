# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP do
  let(:server) { File.expand_path('../fixtures/mcp/server.rb', __dir__) }
  let(:mcp_class) do
    command = [RbConfig.ruby, server]
    Class.new(described_class) { command(*command) }
  end
  let(:mcp) { mcp_class.new }

  after { mcp.close }

  describe 'tools' do
    it 'lists the server tools' do
      expect(mcp.tools.map(&:name)).to eq(%w[echo add fail picture delete_everything])
      expect(mcp.tools.first).to have_attributes(
        description: 'Echoes the text back',
        parameters_schema: { 'type' => 'object', 'properties' => { 'text' => { 'type' => 'string' } },
                             'required' => ['text'] }
      )
    end

    it 'reads the server annotations' do
      echo, add, *, delete_everything = mcp.tools

      expect(echo).to be_read_only
      expect(echo).not_to be_destructive
      expect(add).to be_destructive
      expect(add).to be_open_world
      expect(delete_everything).to be_destructive
      expect(delete_everything).not_to be_open_world
    end

    it 'calls a tool the way a chat does' do
      expect(mcp.tools.first.call(text: 'hello', tool_call: nil)).to eq('hello')
    end

    it 'reports a failed tool as an error for the model' do
      expect(mcp.tools.find { |tool| tool.name == 'fail' }.call).to eq(error: 'Something broke')
    end
  end

  describe '#call' do
    it 'returns the result' do
      result = mcp.call(:add, a: 2, b: 3)

      expect(result).to have_attributes(text: '5', structured: { 'sum' => 5 })
      expect(result).not_to be_error
    end

    it 'turns images into attachments' do
      result = mcp.call(:picture)

      expect(result.text).to eq("Here it is\n\npixel.png: file:///pixel.png")
      expect(result.attachments.first).to have_attributes(mime_type: 'image/png', filename: 'image.png')
      expect(result.content).to eq([result.text, result.attachments.first])
    end
  end

  it 'exposes every server tool as a method' do
    expect(mcp.echo(text: 'hi').text).to eq('hi')
    expect(mcp).to respond_to(:echo)
    expect { mcp.unknown_tool }.to raise_error(NoMethodError)
  end

  it 'reads what the server says about itself' do
    expect(mcp.instructions).to eq('A server for specs.')
    expect(mcp.version).to eq('1.0.0')
  end

  describe 'inputs' do
    let(:mcp_class) do
      Class.new(described_class) do
        url 'https://mcp.example.com/mcp'
        inputs :user
        bearer_token { user.fetch(:token) }
        header 'X-Account', :account_id

        private

        def account_id = user.fetch(:account)
      end
    end
    let(:mcp) { mcp_class.new(user: { token: 'secret', account: 'acme' }) }

    it 'makes inputs available to blocks and methods' do
      stub_request(:post, 'https://mcp.example.com/mcp').to_return(
        headers: { 'Content-Type' => 'application/json' },
        body: ->(request) { { jsonrpc: '2.0', id: JSON.parse(request.body)['id'], result: {} }.to_json }
      )

      mcp.instructions

      expect(
        a_request(:post, 'https://mcp.example.com/mcp')
          .with(headers: { 'Authorization' => 'Bearer secret', 'X-Account' => 'acme' })
      ).to have_been_made
    end

    it 'rejects unknown inputs' do
      expect { mcp_class.new(account: 'acme') }.to raise_error(ArgumentError, 'Unknown MCP inputs: account')
    end
  end

  it 'passes its settings to subclasses' do
    parent = Class.new(described_class) do
      url 'https://mcp.example.com/mcp'
      header 'X-Team', 'core'
    end
    child = Class.new(parent) { header 'X-Extra', 'yes' }

    expect(child.url).to eq('https://mcp.example.com/mcp')
    expect(child.headers).to eq('X-Team' => 'core', 'X-Extra' => 'yes')
    expect(parent.headers).to eq('X-Team' => 'core')
  end

  it 'names itself after its class' do
    stub_const('GoogleDrive', Class.new(described_class))

    expect(GoogleDrive.new.name).to eq('google_drive')
  end

  it 'needs a url or a command' do
    expect { Class.new(described_class).new.tools }.to raise_error(RubyLLM::ConfigurationError, /url or a command/)
  end

  describe '.mcp' do
    it 'builds an MCP inline' do
      docs = RubyLLM.mcp(url: 'https://learn.microsoft.com/api/mcp', bearer_token: 'secret')

      expect(docs).to be_a(described_class)
      expect(docs.name).to eq('learn_microsoft')
      expect(docs.inspect).to eq('#<RubyLLM::MCP name: "learn_microsoft", url: "https://learn.microsoft.com/api/mcp">')
    end

    it 'accepts a name' do
      expect(RubyLLM.mcp(command: %w[npx server], name: 'files').name).to eq('files')
    end
  end
end
