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
      expect(mcp.tools.map(&:name)).to eq(%w[echo add fail picture slow wait deploy connect delete_everything])
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

  describe 'shaping tools' do
    def shaped(&)
      command = [RbConfig.ruby, server]
      Class.new(described_class) do
        command(*command)
        class_eval(&)
      end.new
    end

    it 'keeps only the named tools' do
      mcp = shaped { only :echo, :add }

      expect(mcp.tools.map(&:name)).to eq(%w[echo add])
    ensure
      mcp&.close
    end

    it 'hides the named tools' do
      mcp = shaped { except :delete_everything, :fail }

      expect(mcp.tools.map(&:name)).to eq(%w[echo add picture slow wait deploy connect])
    ensure
      mcp&.close
    end

    it 'renames and redescribes a tool' do
      mcp = shaped { tool :echo, as: :repeat, description: 'Repeats the text' }
      repeat = mcp.tools.first

      expect(repeat).to have_attributes(name: 'repeat', server_name: 'echo', description: 'Repeats the text')
      expect(repeat.call(text: 'hi')).to eq('hi')
      expect(repeat.inspect).to eq('#<RubyLLM::MCP::Tool name: "repeat", from: "echo", read_only: true>')
    ensure
      mcp&.close
    end

    it 'fixes arguments the model no longer sees' do
      mcp = shaped do
        tool :add, fixed_arguments: { b: 10, a: -> { 5 } }
      end
      add = mcp.tools.find { |tool| tool.name == 'add' }

      expect(add.parameters_schema).to eq('type' => 'object', 'properties' => {}, 'required' => [])
      expect(add.call).to eq('15')
    ensure
      mcp&.close
    end

    it 'wraps results with a method' do
      mcp = shaped do
        tool :add, wrap: :describe_sum

        private

        def describe_sum(result, **terms)
          "#{terms.values.join(' + ')} = #{result.structured['sum']}"
        end
      end

      expect(mcp.tools.find { |tool| tool.name == 'add' }.call('a' => 2, 'b' => 3)).to eq('2 + 3 = 5')
    ensure
      mcp&.close
    end

    it 'adds Tool classes that receive the MCP' do
      doubler = Class.new(RubyLLM::Tool) do
        def self.tool_name = 'double'

        def initialize(mcp)
          super()
          @mcp = mcp
        end

        def execute(number:)
          @mcp.add(a: number, b: number).text
        end
      end
      mcp = shaped { tool doubler }

      expect(mcp.tools.last.call(number: 21)).to eq('42')
    ensure
      mcp&.close
    end

    it 'requires approval for the named tools and by annotation' do
      mcp = shaped do
        requires_approval :echo
        requires_approval if: :destructive?
      end
      approvals = mcp.tools.to_h { |tool| [tool.name, tool.requires_approval?] }

      expect(approvals.values.uniq).to eq([true])
    ensure
      mcp&.close
    end

    it 'requires approval when a lambda says so' do
      mcp = shaped { requires_approval if: ->(tool) { tool.name.start_with?('delete') } }

      expect(mcp.tools.select(&:requires_approval?).map(&:name)).to eq(['delete_everything'])
    ensure
      mcp&.close
    end

    it 'refuses declarations for tools the server does not offer' do
      mcp = shaped { tool :read_file, as: :drive_read }

      expect { mcp.tools }.to raise_error(RubyLLM::ConfigurationError, /declares read_file/)
    ensure
      mcp&.close
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

  describe 'resources' do
    it 'lists resources and reads them when needed' do
      readme, pixel = mcp.resources

      expect(readme).to have_attributes(uri: 'file:///project/README.md', name: 'README.md', mime_type: 'text/markdown')
      expect(readme.content).to eq("# Spec Project\n")
      expect(pixel.to_blob.bytesize).to eq(70)
    end

    it 'reads a resource by URI' do
      expect(mcp.resource('file:///project/notes.txt').content).to eq('Contents of file:///project/notes.txt')
    end

    it 'fills in resource templates' do
      template = mcp.resource_templates.first

      expect(template).to have_attributes(uri: 'file:///project/{+path}', name: 'Project files')
      expect(mcp.resource(template.uri, path: 'app/models/user.rb').uri).to eq('file:///project/app/models/user.rb')
    end

    it 'saves resources' do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'README.md')

        expect(mcp.resources.first.save(path)).to eq(path)
        expect(File.read(path)).to eq("# Spec Project\n")
      end
    end

    it 'becomes an attachment' do
      attachment = RubyLLM::Attachment.wrap(mcp.resources.last).first

      expect(attachment).to have_attributes(filename: 'pixel.png', mime_type: 'image/png')
    end
  end

  describe 'prompts' do
    it 'lists prompts with their arguments' do
      prompt = mcp.prompts.first

      expect(prompt).to have_attributes(name: 'code_review', description: 'Reviews code', messages: [])
      expect(prompt.arguments.map(&:name)).to eq(%i[code language])
      expect(prompt.arguments.map(&:required?)).to eq([true, false])
    end

    it 'fills in a prompt' do
      prompt = mcp.prompt(:code_review, code: 'puts 1', language: 'Ruby')

      expect(prompt.messages.map(&:role)).to eq(%i[user assistant user])
      expect(prompt.messages.first.content).to eq("Review this Ruby code:\nputs 1")
    end

    it 'suggests argument values' do
      prompt = mcp.prompts.first

      expect(prompt.suggest(language: 'r')).to eq(%w[ruby rust])
      expect(prompt.suggest(language: 'py', code: 'x = 1')).to eq(['python (x = 1)'])
      expect(mcp.resource_templates.first.suggest(path: 'ru')).to eq(%w[ruby rust])
    end
  end

  describe 'progress' do
    let(:mcp_class) do
      command = [RbConfig.ruby, server]
      Class.new(described_class) do
        command(*command)
        after_progress :record_progress
        after_progress { |progress| reports << progress.message }

        def reports = @reports ||= []

        private

        def record_progress(progress) = reports << progress.fraction
      end
    end

    it 'runs callbacks as the server reports progress' do
      expect(mcp.slow.text).to eq('Finished')
      expect(mcp.reports).to eq([0.5, nil, 1.0, nil])
    end

    it 'takes a method name or a block' do
      expect { Class.new(described_class) { after_progress } }.to raise_error(ArgumentError, /method name or a block/)
    end
  end

  describe 'input requests' do
    def mcp_answering(&)
      command = [RbConfig.ruby, server]
      Class.new(described_class) do
        command(*command)
        before_input_request(&)
      end.new
    end

    it 'answers form requests with a callback and retries the call' do
      mcp = mcp_answering { |request| request.answer(environment: request.fields.first.choices.first) }

      expect(mcp.deploy.text).to eq('Deployed to staging')
    ensure
      mcp&.close
    end

    it 'describes the fields a form asks for' do
      requests = []
      mcp = mcp_answering do |request|
        requests << request
        request.decline
      end

      expect(mcp.deploy.text).to eq('Deploy cancelled')
      expect(requests.first).to have_attributes(message: 'Which environment?', url: nil)
      expect(requests.first).to be_form
      expect(requests.first.fields.first).to have_attributes(name: :environment, title: 'Environment',
                                                             choices: %w[staging production])
      expect(requests.first.fields.first).to be_required
    ensure
      mcp&.close
    end

    it 'accepts URL requests' do
      mcp = mcp_answering { |request| request.answer if request.url? }

      expect(mcp.connect.text).to eq('Connected')
    ensure
      mcp&.close
    end

    it 'raises when no callback answers' do
      expect { mcp.connect }.to raise_error(RubyLLM::MCP::InputRequiredError) do |error|
        expect(error.message).to end_with('needs input from the user: Connect your account https://example.com/connect')
        expect(error.requests.first).to be_url
      end
    end

    it 'tells the model what the server needs when no callback answers' do
      connect = mcp.tools.find { |tool| tool.name == 'connect' }

      expect(connect.call).to eq(error: "#{mcp.name} needs input from the user: " \
                                        'Connect your account https://example.com/connect')
    end

    it 'declares form input only when a callback can answer it' do
      answering = mcp_answering(&:decline)

      expect(mcp.send(:client).request('meta/echo').dig('meta', 'io.modelcontextprotocol/clientCapabilities'))
        .to eq('elicitation' => { 'url' => {} })
      expect(answering.send(:client).request('meta/echo').dig('meta', 'io.modelcontextprotocol/clientCapabilities'))
        .to eq('elicitation' => { 'form' => {}, 'url' => {} })
    ensure
      answering&.close
    end
  end

  describe 'cancellation' do
    it 'stops waiting and tells the server when the chat is cancelled' do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      checkpoint = lambda do
        raise RubyLLM::CancelledError if Process.clock_gettime(Process::CLOCK_MONOTONIC) - started > 0.2
      end

      expect { RubyLLM::Support::Cancellation.watch(checkpoint) { mcp.wait } }.to raise_error(RubyLLM::CancelledError)
      expect(mcp.send(:client).request('spec/cancelled')['cancelled'].size).to eq(1)
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
