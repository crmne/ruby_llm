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

    it 'reads the _meta of each tool' do
      echo, add, = mcp.tools

      expect(add.meta).to eq('com.example/owner' => 'math')
      expect(echo.meta).to eq({})
    end

    it 'calls a tool the way a chat does and returns the server result' do
      result = mcp.tools.first.call(text: 'hello', tool_call: nil)

      expect(result).to be_a(RubyLLM::MCP::Result)
      expect(RubyLLM::Tool.split_result(result)).to eq(['hello', []])
    end

    it 'reports a failed tool as an error for the model, as 2.0 did' do
      result = mcp.tools.find { |tool| tool.name == 'fail' }.call

      expect(result).to eq(error: 'Something broke')
      expect(RubyLLM::Tool.split_result(result)).to eq(['{"error":"Something broke"}', []])
    end

    it 'sends the model the attachments of a result' do
      result = mcp.tools.find { |tool| tool.name == 'picture' }.call

      text, attachments = RubyLLM::Tool.split_result(result)
      expect(text).to eq("Here it is\n\npixel.png: file:///pixel.png")
      expect(attachments.first).to have_attributes(mime_type: 'image/png')
    end

    it 'lists them again after the server answers that a tool it called does not exist' do
      expect(mcp.tools.map(&:name)).to include('delete_everything')
      mcp.send(:client).request('spec/remove_tool', { name: 'delete_everything' })

      expect { mcp.call(:delete_everything) }.to raise_error(RubyLLM::MCP::Error, 'Unknown tool: delete_everything')
      expect(mcp.tools.map(&:name)).not_to include('delete_everything')
    end

    it 'lists them again after the server answers a tool call with method not found' do
      transport = Class.new do
        attr_reader :listings

        def request(message, **)
          @listings = listings.to_i + 1 if message[:method] == 'tools/list'
          reply = case message[:method]
                  when 'server/discover' then { result: { supportedVersions: ['2026-07-28'] } }
                  when 'tools/list' then { result: { tools: [{ name: 'gone', inputSchema: {} }] } }
                  else { error: { code: -32_601, message: 'Method not found' } }
                  end
          JSON.parse({ jsonrpc: '2.0', id: message[:id], **reply }.to_json)
        end

        def notify(*, **) = nil
        def cancel(*, **) = nil
        def close = nil
      end.new
      flaky = RubyLLM.mcp(transport:, name: 'flaky')

      flaky.tools
      expect { flaky.call(:gone) }.to raise_error(RubyLLM::MCP::Error, 'Method not found')
      flaky.tools

      expect(transport.listings).to eq(2)
    end

    context 'with a server that predates 2026-07-28' do
      let(:mcp_class) do
        command = [RbConfig.ruby, server]
        Class.new(described_class) do
          command(*command)
          env MCP_ERA: 'legacy'
        end
      end

      it 'lists them again after the server says they changed during a request' do
        expect(mcp.tools.map(&:name)).not_to include('extra_9')

        mcp.send(:client).request('spec/change_tools')

        expect(mcp.tools.map(&:name)).to include('extra_9')
      end

      it 'starts a new session after the server process restarts' do
        mcp.tools
        expect { mcp.send(:client).request('spec/exit') }.to raise_error(RubyLLM::MCP::Error, /exited/)

        expect(mcp.send(:client).request('tools/list')['tools']).not_to be_empty
      end
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

    it 'prefixes tool names, except for renamed tools' do
      mcp = shaped do
        prefix :files
        tool :echo, as: :repeat
      end

      expect(mcp.tools.map(&:name)).to eq(%w[repeat files_add files_fail files_picture files_slow files_wait
                                             files_deploy files_connect files_delete_everything])
      expect(mcp.tools.last.server_name).to eq('delete_everything')
    ensure
      mcp&.close
    end

    it 'renames and redescribes a tool' do
      mcp = shaped { tool :echo, as: :repeat, description: 'Repeats the text' }
      repeat = mcp.tools.first

      expect(repeat).to have_attributes(name: 'repeat', server_name: 'echo', description: 'Repeats the text')
      expect(repeat.call(text: 'hi').text).to eq('hi')
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
      expect(add.call.text).to eq('15')
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

      expect(result).to have_attributes(text: '5', structured: { 'sum' => 5 }, meta: { 'com.example/exact' => true })
      expect(result).not_to be_error
      expect(mcp.call(:echo, text: 'hi').meta).to eq({})
    end

    it 'returns a failed result whole, with its text as content' do
      result = mcp.call(:fail)

      expect(result).to be_error
      expect(result).to have_attributes(text: 'Something broke', content: 'Something broke')
    end

    it 'answers what the server asks mid-call, pings with a result and everything else with method not found' do
      answers = JSON.parse(mcp.call(:ask_client).text)

      unsupported = { 'code' => -32_601, 'message' => 'Method not found' }
      expect(answers).to eq('ping-1' => {}, 'roots-1' => unsupported, 'sample-1' => unsupported,
                            'elicit-1' => unsupported)
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

    it 'reads the _meta of resources and of their contents' do
      readme = mcp.resource('file:///project/README.md')

      expect(readme).to have_attributes(mime_type: 'text/markdown', meta: { 'com.example/etag' => 'v2' })
      expect(mcp.resources.first.meta).to eq('com.example/listed' => true)
      expect(mcp.resource('file:///project/notes.txt').meta).to eq({})
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

    it 'raises from a tool when no callback answers' do
      connect = mcp.tools.find { |tool| tool.name == 'connect' }

      expect { connect.call }.to raise_error(RubyLLM::MCP::InputRequiredError)
    end

    it 'declares form and URL input to the server' do
      expect(mcp.send(:client).request('meta/echo').dig('meta', 'io.modelcontextprotocol/clientCapabilities'))
        .to eq('elicitation' => { 'form' => {}, 'url' => {} })
    end

    def mcp_accepting(*kinds, &)
      command = [RbConfig.ruby, server]
      Class.new(described_class) do
        command(*command)
        input_requests(*kinds)
        before_input_request(&) if block_given?
      end.new
    end

    it 'declares only the input it accepts' do
      mcp = mcp_accepting(:url)

      expect(mcp.send(:client).request('meta/echo').dig('meta', 'io.modelcontextprotocol/clientCapabilities'))
        .to eq('elicitation' => { 'url' => {} })
    ensure
      mcp&.close
    end

    it 'declares no input when it accepts none' do
      mcp = mcp_accepting(false)

      expect(mcp.class.input_requests).to eq([])
      expect(mcp.send(:client).request('meta/echo').dig('meta', 'io.modelcontextprotocol/clientCapabilities'))
        .to eq({})
    ensure
      mcp&.close
    end

    it 'declines requests it does not accept without asking its callbacks' do
      asked = []
      mcp = mcp_accepting(:url) { |request| asked << request }

      expect(mcp.deploy.text).to eq('Deploy cancelled')
      expect(asked).to be_empty
    ensure
      mcp&.close
    end

    it 'refuses kinds of input it does not know' do
      expect { Class.new(described_class) { input_requests :email } }
        .to raise_error(ArgumentError, 'Unknown input requests: email')
    end
  end

  describe 'listening' do
    let(:changes) { Queue.new }
    let(:mcp_class) { listening_to(server) }

    def listening_to(server, **env)
      command = [RbConfig.ruby, server]
      changes = self.changes
      Class.new(described_class) do
        command(*command)
        env(**env)
        after_change { |change| changes << (change.is_a?(RubyLLM::MCP::Resource) ? change.content : change) }
      end
    end

    def next_change
      Timeout.timeout(5) { changes.pop }
    end

    def ask(mcp, method, **params)
      mcp.send(:client).request(method, params)
    end

    def eventually
      Timeout.timeout(5) do
        loop do
          result = yield
          return result if result

          sleep 0.01
        end
      end
    end

    def subscriptions(mcp)
      ask(mcp, 'spec/subscriptions')['subscriptions']
    end

    def listener_threads
      Thread.list.count { |thread| thread.name == 'ruby_llm-mcp-listener' && thread.alive? }
    end

    before do
      stub_const('RubyLLM::MCP::Listener::RETRY_DELAY', 0.01)
      allow(RubyLLM.logger).to receive(:warn)
    end

    it 'subscribes to the lists the server announces changes to' do
      mcp.listen

      expect(subscriptions(mcp).values)
        .to eq([{ 'toolsListChanged' => true, 'promptsListChanged' => true, 'resourcesListChanged' => true }])
    end

    it 'lists tools again and runs after_change when the server changes them' do
      mcp.listen.tools

      ask(mcp, 'spec/change_tools')

      expect(next_change).to eq(:tools)
      expect(mcp.tools.map(&:name)).to include('extra_9')
    end

    it 'hears changes that arrive while no request is reading' do
      mcp.listen

      ask(mcp, 'spec/announce_later', method: 'notifications/prompts/list_changed')

      expect(next_change).to eq(:prompts)
    end

    it 'hears when a resource it listens to changes, and lets the callback read it' do
      mcp.listen(resources: [mcp.resources.first])

      ask(mcp, 'spec/announce', method: 'notifications/resources/updated',
                                params: { uri: 'file:///project/README.md' })

      expect(next_change).to eq("# Spec Project\n")
    end

    it 'replaces the resources it listens to, cancelling the old subscription' do
      mcp.listen(resources: ['file:///a'])
      first = subscriptions(mcp).keys

      mcp.listen(resources: ['file:///b'])

      expect(subscriptions(mcp).values.map { |filter| filter['resourceSubscriptions'] }).to eq([['file:///b']])
      expect(ask(mcp, 'spec/cancelled')['cancelled']).to eq(first)
    end

    it 'raises and stops listening when the server does not watch a resource' do
      expect { mcp.listen(resources: ['unwatched:notes']) }
        .to raise_error(RubyLLM::MCP::Error, /does not send updates for unwatched:notes/)
      expect(subscriptions(mcp)).to be_empty
    end

    it 'subscribes again when the server ends the subscription' do
      mcp.listen
      first = subscriptions(mcp)

      ask(mcp, 'spec/end_subscriptions')

      renewed = eventually { subscriptions(mcp).except(*first.keys).presence }
      expect(renewed.values).to eq(first.values)
    end

    it 'runs after_change for everything it listens to once it subscribes again, since changes in between are lost' do
      mcp.listen(resources: ['file:///project/README.md'])

      ask(mcp, 'spec/end_subscriptions')

      expect(Array.new(4) { next_change }).to eq([:tools, :prompts, :resources, "# Spec Project\n"])
    end

    it 'subscribes again when the server cancels the subscription' do
      mcp.listen
      first = subscriptions(mcp)

      ask(mcp, 'spec/cancel_subscriptions')

      renewed = eventually { subscriptions(mcp).except(*first.keys).presence }
      expect(renewed.values).to eq(first.values)
    end

    it 'subscribes again after the server exits' do
      mcp.listen

      expect { ask(mcp, 'spec/exit') }.to raise_error(RubyLLM::MCP::Error, /exited/)

      expect(eventually { subscriptions(mcp).presence }.size).to eq(1)
    end

    it 'logs a callback that raises and keeps listening' do
      allow(RubyLLM.logger).to receive(:error)
      calls = 0
      mcp_class.after_change { |change| raise 'Callback failed' if change == :prompts && (calls += 1) == 1 }
      mcp.listen

      2.times { ask(mcp, 'spec/announce', method: 'notifications/prompts/list_changed') }

      expect([next_change, next_change]).to eq(%i[prompts prompts])
      eventually { calls == 2 }
      expect(RubyLLM.logger).to have_received(:error).once
    end

    it 'stops its thread when the MCP closes' do
      before = listener_threads
      mcp.listen
      expect(listener_threads).to eq(before + 1)

      mcp.close

      expect(listener_threads).to eq(before)
    end

    it 'does nothing for a server that announces no changes' do
      quiet = listening_to(server, MCP_CHANGES: 'none').new

      expect(quiet.listen).to be(quiet)
      expect(subscriptions(quiet)).to be_empty
    ensure
      quiet&.close
    end

    it 'listens in a forked child only once the child asks' do
      skip 'fork is unavailable' unless Process.respond_to?(:fork)

      mcp.listen
      child = fork do
        inherited = listener_threads
        mcp.listen
        ask(mcp, 'spec/change_tools')
        exit!(inherited.zero? && next_change == :tools ? 0 : 1)
      end
      Process.wait(child)

      expect(Process.last_status.exitstatus).to eq(0)
      ask(mcp, 'spec/change_tools')
      expect(next_change).to eq(:tools)
    end

    context 'with tasks' do
      before { mcp_class.extension :tasks }

      def report = mcp.tools.find { |tool| tool.name == 'report' }.call

      it 'hears when the status of a task it listens to changes, with the task as it stands' do
        task = report
        mcp.listen(tasks: [task])

        ask(mcp, 'spec/announce', method: 'notifications/tasks',
                                  params: { taskId: task.id, status: 'completed',
                                            result: { content: [{ type: 'text', text: 'Report ready' }] } })

        change = next_change
        expect(change).to have_attributes(class: RubyLLM::MCP::Task, id: task.id, status: :completed)
        expect(change.result.text).to eq('Report ready')
        expect(subscriptions(mcp).values.map { |filter| filter['taskIds'] }).to eq([[task.id]])
      end

      it 'checks on the tasks it listens to once it subscribes again' do
        task = report
        mcp.listen(tasks: [task])

        ask(mcp, 'spec/end_subscriptions')

        *lists, change = Array.new(4) { next_change }
        expect(lists).to eq(%i[tools prompts resources])
        expect(change).to have_attributes(id: task.id, status: :working, status_message: 'Rendering')
      end

      it 'raises and stops listening when the server does not send the status of a task' do
        expect { mcp.listen(tasks: ['task-404']) }
          .to raise_error(RubyLLM::MCP::Error, /does not send updates for task-404/)
        expect(subscriptions(mcp)).to be_empty
      end
    end

    context 'with a server that predates subscriptions' do
      let(:mcp_class) { listening_to(server, MCP_ERA: 'legacy') }

      it 'subscribes to resources and hears the changes the server announces' do
        mcp.listen(resources: ['file:///project/README.md'])

        ask(mcp, 'spec/announce_later', method: 'notifications/tools/list_changed')

        expect(next_change).to eq(:tools)
        expect(ask(mcp, 'spec/subscriptions')['watched']).to eq(['file:///project/README.md'])
      end

      it 'starts a new session once the server process restarts, and catches up once' do
        mcp.listen

        expect { ask(mcp, 'spec/exit') }.to raise_error(RubyLLM::MCP::Error, /exited/)

        expect(Array.new(3) { next_change }).to eq(%i[tools prompts resources])
        expect { Timeout.timeout(0.5) { changes.pop } }.to raise_error(Timeout::Error)
        ask(mcp, 'spec/announce_later', method: 'notifications/tools/list_changed')
        expect(next_change).to eq(:tools)
      end

      it 'raises for tasks, whose status such a server never announces' do
        expect { mcp.listen(tasks: ['task-1']) }
          .to raise_error(RubyLLM::MCP::Error, /does not send updates for task-1/)
      end

      it 'unsubscribes from resources it no longer listens to' do
        mcp.listen(resources: ['file:///a', 'file:///b'])

        mcp.listen(resources: ['file:///b'])

        expect(ask(mcp, 'spec/subscriptions')['watched']).to eq(['file:///b'])
      end

      it 'runs after_change for changes announced while it answers a request' do
        ask(mcp, 'spec/change_tools')

        expect(next_change).to eq(:tools)
      end
    end
  end

  describe 'extensions' do
    def mcp_declaring(&)
      command = [RbConfig.ruby, server]
      Class.new(described_class) do
        command(*command)
        class_eval(&)
      end.new
    end

    def declared(mcp)
      mcp.send(:client).request('meta/echo').dig('meta', 'io.modelcontextprotocol/clientCapabilities', 'extensions')
    end

    it 'declares extensions and their settings with every request' do
      mcp = mcp_declaring do
        extension 'com.example/audit', level: 'full'
        extension 'com.example/replay'
      end

      expect(declared(mcp)).to eq('com.example/audit' => { 'level' => 'full' }, 'com.example/replay' => {})
    ensure
      mcp&.close
    end

    it 'declares none unless asked' do
      expect(declared(mcp)).to be_nil
    end

    it 'refuses names without a vendor prefix' do
      expect { Class.new(described_class) { extension 'audit' } }.to raise_error(ArgumentError, /vendor prefix/)
    end

    it 'refuses names of extensions it does not know' do
      expect { Class.new(described_class) { extension :widgets } }
        .to raise_error(ArgumentError, 'Unknown MCP extension: widgets')
    end

    it 'passes extensions to subclasses without sharing them' do
      parent = Class.new(described_class) { extension 'com.example/audit' }
      child = Class.new(parent) { extension 'com.example/replay' }

      expect(child.extensions.keys).to eq(%w[com.example/audit com.example/replay])
      expect(parent.extensions.keys).to eq(%w[com.example/audit])
    end
  end

  describe 'MCP Apps' do
    let(:mcp_class) do
      command = [RbConfig.ruby, server]
      Class.new(described_class) do
        command(*command)
        extension :apps
      end
    end

    def tool(name) = mcp.tools.find { |tool| tool.name == name }

    it 'declares UIs written in HTML' do
      capabilities = mcp.send(:client).request('meta/echo').dig('meta', 'io.modelcontextprotocol/clientCapabilities')

      expect(capabilities['extensions'])
        .to eq('io.modelcontextprotocol/ui' => { 'mimeTypes' => ['text/html;profile=mcp-app'] })
    end

    it 'declares the settings you give it' do
      mcp_class.extension :apps, mimeTypes: %w[text/html;profile=mcp-app text/uri-list]

      expect(mcp_class.extensions['io.modelcontextprotocol/ui'])
        .to eq('mimeTypes' => %w[text/html;profile=mcp-app text/uri-list])
    end

    it 'lists every tool with its UI and who may call it' do
      expect(tool('forecast')).to have_attributes(ui_uri: 'ui://spec/forecast', visibility: %i[model app])
      expect(tool('refresh_forecast')).to have_attributes(ui_uri: 'ui://spec/forecast', visibility: [:app])
      expect(tool('echo')).to have_attributes(ui_uri: nil, visibility: %i[model app])
    end

    it 'reads a UI and its content security policy through the resource API' do
      view = mcp.resource(tool('forecast').ui_uri)

      expect(view).to have_attributes(mime_type: 'text/html;profile=mcp-app', content: start_with('<!DOCTYPE html>'))
      expect(view.meta['ui']).to eq('csp' => { 'connectDomains' => ['https://api.example.com'] },
                                    'prefersBorder' => true)
    end

    it 'calls tools that only a UI may call' do
      expect(mcp.call(:refresh_forecast)).to have_attributes(text: 'Refreshed', structured: { 'fresh' => true })
      expect(mcp.refresh_forecast.text).to eq('Refreshed')
    end

    it 'names the UI that renders a result' do
      expect(mcp.call(:forecast, city: 'Rome')).to have_attributes(
        ui_uri: 'ui://spec/forecast', structured: { 'city' => 'Rome', 'temperature' => 24 },
        meta: { 'com.example/station' => 'spec' }
      )
      expect(tool('forecast').call(city: 'Rome').ui_uri).to eq('ui://spec/forecast')
      expect(mcp.call(:echo, text: 'hi').ui_uri).to be_nil
    end

    it 'keeps a result with a UI on a message across serialization' do
      result = mcp.call(:forecast, city: 'Rome')
      message = RubyLLM::Message.new(role: :tool, content: result.text, tool_call_id: 'call_1', mcp_result: result)

      copy = RubyLLM::Message.new(message.to_h)

      expect(copy.mcp_result).to have_attributes(ui_uri: 'ui://spec/forecast', to_h: result.to_h)
    end

    it 'reads the URI of a UI written the deprecated way' do
      definition = { 'name' => 'chart', '_meta' => { 'ui/resourceUri' => 'ui://spec/chart' } }

      expect(RubyLLM::MCP::Tool.new(mcp, definition).ui_uri).to eq('ui://spec/chart')
    end

    it 'lists no UI tools to a client that does not declare the extension' do
      command = [RbConfig.ruby, server]
      plain = Class.new(described_class) { command(*command) }.new

      expect(plain.tools.map(&:name)).not_to include('forecast')
    ensure
      plain&.close
    end
  end

  describe 'tasks' do
    let(:mcp_class) do
      command = [RbConfig.ruby, server]
      Class.new(described_class) do
        command(*command)
        extension :tasks
      end
    end

    def tool(name) = mcp.tools.find { |tool| tool.name == name }
    def server_tasks = mcp.send(:client).request('spec/tasks')

    it 'declares the tasks extension' do
      capabilities = mcp.send(:client).request('meta/echo').dig('meta', 'io.modelcontextprotocol/clientCapabilities')

      expect(capabilities['extensions']).to eq('io.modelcontextprotocol/tasks' => {})
    end

    it 'hands a chat the task a tool call becomes' do
      task = tool('report').call

      expect(task).to be_a(RubyLLM::MCP::Task)
      expect(task).to have_attributes(id: 'task-1', status: :working, status_message: 'Queued', poll_interval: 0.01,
                                      expires_at: Time.utc(2026, 10, 2, 10, 1), result: nil)
      expect(task).not_to be_done
    end

    it 'checks on a task once each time you refresh it' do
      task = tool('report').call

      expect(task.refresh).to have_attributes(status: :working, status_message: 'Rendering')
      expect(task.refresh).to be_completed
      expect(task.result).to have_attributes(text: 'Report ready', structured: { 'pages' => 2 })
      expect(task.refresh).to be_done
      expect(server_tasks['polls']).to eq('task-1' => 2)
    end

    it 'waits for a task' do
      expect(tool('report').call.wait.result.text).to eq('Report ready')
    end

    it 'waits for the task of a tool you call directly' do
      expect(mcp.call(:report)).to have_attributes(text: 'Report ready', structured: { 'pages' => 2 })
    end

    it 'reports what a task is doing as progress' do
      messages = []
      mcp_class.after_progress { |progress| messages << progress.message }

      mcp.call(:report)

      expect(messages).to eq(['Rendering'])
    end

    it 'raises the error a task failed with' do
      expect { mcp.call(:broken_report) }.to raise_error(RubyLLM::MCP::Error, 'Renderer crashed') do |error|
        expect(error.code).to eq(-32_603)
      end
      expect(tool('broken_report').call.refresh).to be_failed
    end

    it 'answers the input requests of a task with callbacks' do
      mcp_class.before_input_request { |request| request.answer(approved: true) }

      expect(mcp.call(:approve_report).text).to eq('Approved: true')
    end

    it 'raises when no callback answers the input requests of a task' do
      expect { mcp.call(:approve_report) }.to raise_error(RubyLLM::MCP::InputRequiredError, /Publish the report/)
    end

    it 'cancels a task' do
      task = tool('endless_report').call

      expect(task.cancel).to be(task)
      expect(server_tasks['cancelled']).to eq([task.id])
      expect(task.refresh).to be_cancelled
    end

    it 'stops waiting for a task after the timeout and leaves it to you' do
      task = tool('endless_report').call

      expect do
        task.wait(timeout: 0.05)
      end.to raise_error(RubyLLM::MCP::Error, 'Task task-1 did not finish in 0.05 seconds')
      expect(server_tasks['cancelled']).to be_empty
    end

    it 'cancels the task of a direct call when the chat is cancelled' do
      checks = 0
      checkpoint = -> { raise RubyLLM::CancelledError if (checks += 1) == 5 }

      expect { RubyLLM::Support::Cancellation.watch(checkpoint) { mcp.call(:endless_report) } }
        .to raise_error(RubyLLM::CancelledError)
      expect(server_tasks['cancelled']).to eq(['task-1'])
    end
  end

  describe 'log messages' do
    before { allow(RubyLLM.logger).to receive(:add) }

    it 'writes the messages at the level it asks for and above to the RubyLLM logger' do
      mcp_class.log_level :warning

      mcp.echo(text: 'hi')

      expect(RubyLLM.logger).to have_received(:add).with(Logger::WARN, "#{mcp.name} (echo): {\"slow\":true}").once
      expect(RubyLLM.logger).not_to have_received(:add).with(Logger::DEBUG, anything)
    end

    it 'asks for messages down to debug' do
      mcp_class.log_level :debug

      mcp.echo(text: 'hi')

      expect(RubyLLM.logger).to have_received(:add).with(Logger::DEBUG, "#{mcp.name} (echo): Echoing")
    end

    it 'asks for no messages unless you set a level' do
      mcp.echo(text: 'hi')

      expect(RubyLLM.logger).not_to have_received(:add)
    end

    it 'refuses levels the protocol does not define' do
      expect { Class.new(described_class) { log_level :verbose } }
        .to raise_error(ArgumentError, 'Unknown MCP log level: verbose')
    end

    it 'takes a level inline' do
      expect(RubyLLM.mcp(url: 'https://mcp.linear.app/mcp', log_level: :info).class.log_level).to eq(:info)
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
      discovered = { supportedVersions: ['2026-07-28'] }
      stub_request(:post, 'https://mcp.example.com/mcp').to_return(
        headers: { 'Content-Type' => 'application/json' },
        body: ->(request) { { jsonrpc: '2.0', id: JSON.parse(request.body)['id'], result: discovered }.to_json }
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

  it 'names an anonymous class after its server' do
    expect(Class.new(described_class) { url 'https://mcp.linear.app/mcp' }.new.name).to eq('linear')
  end

  it 'needs a url, a command, or a transport' do
    expect { Class.new(described_class).new.tools }
      .to raise_error(RubyLLM::ConfigurationError, /url, a command, or a transport/)
  end

  describe 'transport' do
    let(:tunnel_class) do
      Class.new do
        attr_reader :methods_sent

        def initialize(label = 'tunnel')
          @label = label
          @methods_sent = []
        end

        def request(message, **)
          @methods_sent << message[:method]
          JSON.parse({ jsonrpc: '2.0', id: message[:id], result: result_for(message) }.to_json)
        end

        def notify(*, **) = nil
        def cancel(*, **) = nil

        def close
          @closed = true
        end

        def closed? = @closed || false

        private

        def result_for(message)
          case message[:method]
          when 'server/discover' then { supportedVersions: ['2026-07-28'], serverInfo: { version: @label } }
          when 'tools/list' then { tools: [{ name: 'echo', annotations: { readOnlyHint: true } }] }
          when 'tools/call' then { content: [{ type: 'text', text: message.dig(:params, :arguments, :text) }] }
          end
        end
      end
    end
    let(:tunnel) { tunnel_class.new }

    it 'speaks through the transport it is given' do
      mcp = RubyLLM.mcp(transport: tunnel, name: 'tunnelled', prefix: 'remote')

      expect(mcp.tools.map(&:name)).to eq(['remote_echo'])
      expect(mcp.tools.first.call(text: 'hi').text).to eq('hi')
      expect(tunnel.methods_sent).to eq(%w[server/discover tools/list tools/call])
    end

    it 'builds the transport on the instance' do
      tunnel_class = self.tunnel_class
      mcp_class = Class.new(described_class) do
        inputs :device
        transport { tunnel_class.new(device) }
      end

      expect(mcp_class.new(device: 'laptop').version).to eq('laptop')
    end

    it 'builds the transport with a method' do
      tunnel = self.tunnel
      mcp_class = Class.new(described_class) do
        transport :build_transport

        private

        define_method(:build_transport) { tunnel }
      end

      expect(mcp_class.new.version).to eq('tunnel')
    end

    it 'shares the transport object with subclasses' do
      tunnel = self.tunnel
      parent = Class.new(described_class) { transport tunnel }

      expect(Class.new(parent).transport).to be(tunnel)
    end

    it 'closes the transport' do
      mcp = RubyLLM.mcp(transport: tunnel, name: 'tunnelled')
      mcp.tools
      mcp.close

      expect(tunnel).to be_closed
    end

    it 'does not keep a tool list the server changed while sending it' do
      churning = Class.new(tunnel_class) do
        def request(message, **)
          if message[:method] == 'tools/list' && block_given?
            yield('jsonrpc' => '2.0', 'method' => 'notifications/tools/list_changed')
          end
          super
        end
      end
      tunnel = churning.new
      mcp = RubyLLM.mcp(transport: tunnel, name: 'tunnelled')

      2.times { mcp.tools }

      expect(tunnel.methods_sent.count('tools/list')).to eq(2)
    end

    it 'needs a name inline' do
      expect { RubyLLM.mcp(transport: tunnel) }.to raise_error(ArgumentError, /transport needs a name/)
    end
  end

  describe '.mcp' do
    it 'builds an MCP inline' do
      docs = RubyLLM.mcp(url: 'https://learn.microsoft.com/api/mcp', bearer_token: 'secret')

      expect(docs).to be_a(described_class)
      expect(docs.name).to eq('learn_microsoft')
      expect(docs.inspect).to eq('#<RubyLLM::MCP name: "learn_microsoft", url: "https://learn.microsoft.com/api/mcp">')
    end

    it 'accepts a prefix and OAuth settings' do
      owner = Object.new
      linear = RubyLLM.mcp(url: 'https://mcp.linear.app/mcp', prefix: 'mcp_1', oauth: { owner:, scopes: %w[read] })

      expect(linear.class.prefix).to eq('mcp_1')
      expect(linear.class.oauth_settings).to include(owner:, scopes: %w[read])
    end

    it 'accepts the input requests it takes' do
      expect(RubyLLM.mcp(url: 'https://mcp.linear.app/mcp', input_requests: false).class.input_requests).to eq([])
      expect(RubyLLM.mcp(url: 'https://mcp.linear.app/mcp', input_requests: [:form]).class.input_requests)
        .to eq([:form])
    end

    it 'accepts extensions by name or with settings' do
      url = 'https://mcp.linear.app/mcp'

      expect(RubyLLM.mcp(url:, extensions: 'com.example/replay').class.extensions)
        .to eq('com.example/replay' => {})
      expect(RubyLLM.mcp(url:, extensions: { 'com.example/audit' => { level: 'full' } }).class.extensions)
        .to eq('com.example/audit' => { 'level' => 'full' })
    end

    it 'refuses unknown settings' do
      expect { RubyLLM.mcp(url: 'https://mcp.linear.app/mcp', only: [:search]) }
        .to raise_error(ArgumentError, 'Unknown MCP settings: only')
    end

    it 'accepts a name' do
      expect(RubyLLM.mcp(command: %w[npx server], name: 'files').name).to eq('files')
    end
  end
end
