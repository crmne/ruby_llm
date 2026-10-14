# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:cache_dir) { Dir.mktmpdir('ruby_llm-packages-spec') }
  let(:sandbox) { FakeSandbox.new }
  let(:context) do
    RubyLLM.context do |config|
      config.sandbox = sandbox
      config.package_cache_dir = cache_dir
    end
  end
  let(:chat) { context.chat(model: model_for(:openai), provider: :openai).with_code_execution }

  after { FileUtils.rm_rf(cache_dir) }

  def request(permission, *targets, id: 'call_1')
    RubyLLM::ToolCall.new(id:, name: 'request_permission',
                          arguments: { 'permission' => permission, 'targets' => targets, 'reason' => 'To install' })
  end

  def run_code_call(id: 'call_2')
    RubyLLM::ToolCall.new(id:, name: 'run_code', arguments: { 'language' => 'shell', 'code' => 'echo hi' })
  end

  def respond_with(*calls)
    responses = calls.map do |call|
      RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call })
    end
    allow(chat.provider).to receive(:complete).and_return(*responses,
                                                          RubyLLM::Message.new(role: :assistant, content: 'Done'))
  end

  def result_for(id)
    chat.messages.find { |message| message.tool_call_id == id }&.content
  end

  def last_code_run
    sandbox.code_runs.last
  end

  it 'offers request_permission only with code execution and a permissions mode' do
    expect(chat.tools.keys).to eq([:run_code])
    expect(chat.with_permissions(:ask).tools.keys).to eq(%i[run_code request_permission])
    expect(chat.tools[:run_code].description).to include('request_permission')
    expect(context.chat(model: model_for(:openai), provider: :openai).with_permissions(:ask).tools).to be_empty
    expect(chat.with_code_execution(false).tools).to be_empty
  end

  it 'parks a request under :ask like any approval and widens later runs once approved' do
    chat.with_permissions(:ask)
    respond_with(request('network', 'pypi.org'), run_code_call)

    chat.ask('Install requests')
    expect(chat.pending_approvals.map(&:name)).to eq(['request_permission'])
    expect(chat.pending_approvals.first.arguments['targets']).to eq(['pypi.org'])

    chat.approve(chat.pending_approvals.first).complete

    expect(result_for('call_1')).to include('Granted network access to pypi.org')
    expect(last_code_run[:network]).to eq(allow: ['pypi.org'])
  end

  it 'grants under :auto what allow: covers, exactly as asked' do
    chat.with_permissions(:auto, allow: [{ network: ['*.pythonhosted.org', 'pypi.org'] }])
    respond_with(request('network', 'files.pythonhosted.org', 'PyPI.org:443'), run_code_call)

    chat.ask('Install requests')

    expect(chat).not_to be_waiting
    expect(last_code_run[:network]).to eq(allow: %w[files.pythonhosted.org pypi.org])
  end

  it 'waits under :auto for what allow: does not cover' do
    chat.with_permissions(:auto, allow: [{ network: ['pypi.org'] }])
    respond_with(request('network', 'evil.example'))

    chat.ask('Install requests')

    expect(chat.pending_approvals.map(&:name)).to eq(['request_permission'])
  end

  it 'grants under :dangerous and denies under :read_only' do
    chat.with_permissions(:dangerous)
    respond_with(request('network', 'pypi.org'))
    chat.ask('Go')
    expect(result_for('call_1')).to include('Granted')

    other = context.chat(model: model_for(:openai), provider: :openai).with_code_execution.with_permissions(:read_only)
    allow(other.provider).to receive(:complete).and_return(
      RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { 'call_1' => request('network', 'pypi.org') }),
      RubyLLM::Message.new(role: :assistant, content: 'Done')
    )
    other.ask('Go')
    expect(other.messages.find(&:tool_result?).content).to include('read-only')
  end

  it 'answers an invalid request at once instead of asking the user' do
    chat.with_permissions(:ask)
    respond_with(request('network', '*.example.com'))

    chat.ask('Go')

    expect(chat).not_to be_waiting
    expect(result_for('call_1')).to include('not a host name')
  end

  it 'does not wait for hosts already granted' do
    chat.with_permissions(:ask)
    respond_with(request('network', 'pypi.org'), request('network', 'pypi.org', id: 'call_3'))
    chat.ask('Go')

    chat.approve('call_1').complete

    expect(result_for('call_3')).to include('Granted')
    expect(chat).to be_complete
  end

  it 'remembers only the exact host when approved with remember: true' do
    chat.with_permissions(:ask)
    respond_with(request('network', 'pypi.org'), request('network', 'evil.example', id: 'call_3'))
    chat.ask('Go')

    chat.approve('call_1', remember: true).complete

    expect(chat.pending_approvals.map(&:id)).to eq(['call_3'])
  end

  it 'adds granted hosts to the configured list and leaves full network alone' do
    chat.with_code_execution(network: { allow: ['api.github.com'] }).with_permissions(:dangerous)
    respond_with(request('network', 'pypi.org'), run_code_call)
    chat.ask('Go')

    expect(last_code_run[:network]).to eq(allow: %w[api.github.com pypi.org])
    expect(chat.tools[:run_code].network).to eq(allow: %w[api.github.com pypi.org])
  end

  it 'tells the model it can ask for blocked hosts' do
    sandbox = FakeSandbox.new { FakeSandbox.result(blocked: ['pypi.org:443'], exit_code: 1) }
    chat = RubyLLM.context { |config| config.sandbox = sandbox }
                  .chat(model: model_for(:openai), provider: :openai).with_code_execution

    without_mode = JSON.parse(chat.tools[:run_code].call(language: 'shell', code: 'pip install x'))
    with_mode = JSON.parse(chat.with_permissions(:ask).tools[:run_code].call(language: 'shell', code: 'pip install x'))

    expect(without_mode).not_to have_key('hint')
    expect(with_mode['blocked_hosts']).to eq(['pypi.org:443'])
    expect(with_mode['hint']).to include('request_permission')
  end

  describe 'path grants' do
    let(:data) { Dir.mktmpdir('ruby_llm-data') }

    after { FileUtils.rm_rf(data) }

    it 'mounts granted paths, resolving symbolic links, writable over readable' do
      link = File.join(Dir.mktmpdir('ruby_llm-link'), 'data')
      File.symlink(data, link)
      chat.with_permissions(:dangerous)
      respond_with(request('readable', link), request('writable', data, id: 'call_3'), run_code_call(id: 'call_4'))

      chat.ask('Go')

      expect(last_code_run[:readable]).not_to include(File.realpath(data))
      expect(last_code_run[:writable]).to include(File.realpath(data))
    end

    it 'mounts a readable grant read-only' do
      chat.with_permissions(:dangerous)
      respond_with(request('readable', data), run_code_call)

      chat.ask('Go')

      expect(last_code_run[:readable]).to include(File.realpath(data))
      expect(last_code_run[:writable]).not_to include(File.realpath(data))
    end

    it 'covers paths inside an allowed directory under :auto' do
      inside = File.join(data, 'reports')
      FileUtils.mkdir_p(inside)
      chat.with_permissions(:auto, allow: [{ readable: [data] }])
      respond_with(request('readable', inside))

      chat.ask('Go')

      expect(result_for('call_1')).to include('Granted read access')
    end

    it 'refuses relative, missing, and root paths' do
      chat.with_permissions(:dangerous)
      tool = chat.tools[:request_permission]

      expect(tool.call(permission: 'readable', targets: ['data'], reason: 'x')[:error]).to include('absolute')
      expect(tool.call(permission: 'readable', targets: ['/nope/x'], reason: 'x')[:error]).to include('does not exist')
      expect(tool.call(permission: 'readable', targets: ['/'], reason: 'x')[:error]).to include('whole file system')
      expect(tool.call(permission: 'disk', targets: ['/'], reason: 'x')[:error]).to include('permission must be')
      expect(tool.call(permission: 'network', targets: [], reason: 'x')[:error]).to include('at least one')
    end

    it 'makes run_code a tool that changes things once a writable path is granted' do
      run_code = chat.tools[:run_code]
      expect(run_code).to be_read_only

      chat.with_permissions(:dangerous)
      respond_with(request('writable', data))
      chat.ask('Go')

      expect(run_code).not_to be_read_only
    end
  end

  describe 'packages the model installs' do
    it 'installs into a writable environment kept for the chat' do
      chat.with_permissions(:dangerous)
      respond_with(request('network', 'rubygems.org'), run_code_call, run_code_call(id: 'call_3'))

      chat.ask('Go')

      environment = File.join(cache_dir, 'chats', chat.send(:sandbox_grants)[:environment])
      first, second = sandbox.code_runs.last(2)
      expect(first[:writable]).to include(environment)
      expect(first[:env]).to include('GEM_HOME' => File.join(environment, 'gems'))
      expect(first[:env]['GEM_PATH']).to start_with(File.join(environment, 'gems'))
      expect(first[:env]['GEM_PATH'].split(File::PATH_SEPARATOR)).not_to include(Gem.default_dir)
      expect(first[:env]['PATH']).to start_with(File.join(environment, 'gems', 'bin'))
      expect(second[:env]['GEM_HOME']).to eq(first[:env]['GEM_HOME'])
    end

    it 'creates a virtualenv once when Python is available' do
      chat.with_code_execution(languages: %i[python shell]).with_permissions(:dangerous)
      respond_with(request('network', 'pypi.org'), run_code_call, run_code_call(id: 'call_3'))

      chat.ask('Go')

      venvs = sandbox.runs.select { |run| run[:command][0, 3] == %w[python3 -m venv] }
      environment = File.join(cache_dir, 'chats', chat.send(:sandbox_grants)[:environment])
      expect(venvs.size).to eq(1)
      expect(venvs.first[:network]).to be(false)
      expect(sandbox.code_runs.last[:env]).to include('VIRTUAL_ENV' => File.join(environment, 'python'))
    end

    it 'leaves runs as they were until a host is granted' do
      chat.tools[:run_code].call(language: 'shell', code: 'echo hi')

      expect(last_code_run[:env]).not_to have_key('GEM_HOME')
      expect(last_code_run[:network]).to be(false)
    end
  end

  describe 'asking for access', :live do
    let(:registry) { %w[pypi.org files.pythonhosted.org] }
    let(:sandbox) do
      hosts = registry
      FakeSandbox.new do |run|
        allowed = run[:network].is_a?(Hash) ? run[:network][:allow] : []
        missing = hosts - allowed
        if !run[:command].last.to_s.match?(/main\.(py|sh)\z/)
          FakeSandbox.result
        elsif missing.empty?
          FakeSandbox.result(stdout: "Successfully installed requests-2.32.3\n2.32.3\n")
        else
          FakeSandbox.result(stderr: 'ProxyError: Cannot connect to proxy. 403 Forbidden', exit_code: 1,
                             blocked: missing.map { |host| "#{host}:443" })
        end
      end
    end

    %i[openai anthropic].each do |provider|
      model = model_for(provider)

      it "#{provider}/#{model} asks for the registry and installs once approved" do
        chat = context.chat(model:, provider:)
                      .with_code_execution(languages: %i[python shell]).with_permissions(:ask)

        chat.ask 'Install the requests Python package with pip, then tell me which version you installed.'
        requests = []
        4.times do
          break unless chat.awaiting_approval?

          chat.pending_approvals.each do |call|
            requests << call
            chat.approve(call)
          end
          chat.complete
        end

        expect(requests.map(&:name).uniq).to eq(['request_permission'])
        expect(requests.flat_map { |call| call.arguments['targets'] }).to include('pypi.org')
        expect(chat).to be_complete
        expect(chat.messages.last.content).to include('2.32.3')
        expect(sandbox.code_runs.last[:network][:allow]).to include(*registry)
      end
    end
  end
end
