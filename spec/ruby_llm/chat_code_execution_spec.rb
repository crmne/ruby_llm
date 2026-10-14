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
  let(:chat) { context.chat(model: model_for(:openai), provider: :openai) }
  let(:fixture_png) { File.expand_path('../fixtures/ruby.png', __dir__) }

  after { FileUtils.rm_rf(cache_dir) }

  def tool_call(code:, language: 'ruby', id: 'call_1')
    RubyLLM::ToolCall.new(id:, name: 'run_code', arguments: { 'language' => language, 'code' => code })
  end

  def run_code(code, language: 'ruby')
    chat.tools[:run_code].call(language:, code:)
  end

  def report(result)
    JSON.parse(Array(result).first)
  end

  def writing(files)
    FakeSandbox.new do |run|
      files.each do |name, content|
        path = File.join(run[:directory], name)
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, content)
      end
      FakeSandbox.result(stdout: 'done')
    end
  end

  describe '#with_code_execution' do
    it 'enables code execution with Ruby and shell by default' do
      expect(chat.with_code_execution).to be(chat)
      expect(chat.code_execution).to eq(languages: %i[ruby shell])
      expect(chat.tools.keys).to include(:run_code)
    end

    it 'accepts options as keywords or a Hash' do
      chat.with_code_execution(languages: [:python], gems: %w[prawn])
      expect(chat.code_execution).to eq(languages: [:python], gems: %w[prawn])

      chat.with_code_execution({ 'languages' => ['ruby'] })
      expect(chat.code_execution).to eq(languages: [:ruby])
    end

    it 'adds Python when Python packages are declared' do
      chat.with_code_execution(python: %w[pandas])

      expect(chat.code_execution[:languages]).to eq(%i[ruby python shell])
      expect(chat.with_code_execution(virtualenv: '/opt/venv').code_execution[:languages]).to eq(%i[ruby python shell])
    end

    it 'adds JavaScript when npm packages are declared' do
      chat.with_code_execution(npm: %w[pptxgenjs])

      expect(chat.code_execution[:languages]).to eq(%i[ruby javascript shell])
      expect(chat.with_code_execution(node_modules: '/opt/app/node_modules', python: %w[pandas])
                 .code_execution[:languages]).to eq(%i[ruby python javascript shell])
    end

    it 'disables code execution with false' do
      chat.with_code_execution.with_code_execution(false)

      expect(chat.code_execution).to be(false)
      expect(chat.tools).not_to have_key(:run_code)
    end

    it 'rejects nil, unknown options, unknown languages, and options with false' do
      expect { chat.with_code_execution(nil) }.to raise_error(ArgumentError, /accepts false or code execution/)
      expect { chat.with_code_execution(memory: 1) }.to raise_error(ArgumentError, /got memory/)
      expect { chat.with_code_execution(timeout: 5) }.to raise_error(ArgumentError, /got timeout/)
      expect { chat.with_code_execution(languages: [:cobol]) }.to raise_error(ArgumentError, /got cobol/)
      expect { chat.with_code_execution(languages: []) }.to raise_error(ArgumentError, /at least one language/)
      expect { chat.with_code_execution(gems: nil) }.to raise_error(ArgumentError, /cannot be nil/)
      expect { chat.with_code_execution(false, gems: %w[a]) }.to raise_error(ArgumentError, /does not accept/)
      expect { chat.with_code_execution(gems: %w[a], gem_home: '/g') }.to raise_error(ArgumentError, /not both/)
      expect { chat.with_code_execution(python: %w[a], virtualenv: '/v') }.to raise_error(ArgumentError, /not both/)
      expect { chat.with_code_execution(npm: %w[a], node_modules: '/n') }.to raise_error(ArgumentError, /not both/)
    end

    it 'raises ConfigurationError without a sandbox' do
      plain = RubyLLM.context { |config| config.sandbox = nil }.chat(model: model_for(:openai), provider: :openai)

      expect { plain.with_code_execution }.to raise_error(RubyLLM::ConfigurationError, /config.sandbox/)
    end

    it "runs in the sandbox of the chat's current context" do
      other = FakeSandbox.new
      chat.with_code_execution.with_context(RubyLLM.context { |config| config.sandbox = other })

      run_code('puts 1')

      expect(other.code_runs.size).to eq(1)
      expect(sandbox.code_runs).to be_empty
    end

    it 'raises ConfigurationError when the current context has no sandbox' do
      chat.with_code_execution.with_context(RubyLLM.context { |config| config.sandbox = nil })

      expect { run_code('puts 1') }.to raise_error(RubyLLM::ConfigurationError, /config.sandbox/)
    end

    it 'refuses a tool of the same name' do
      own = Class.new(RubyLLM::Tool) do
        def self.tool_name = 'run_code'
        def execute = 'mine'
      end
      chat.with_tools(own).with_code_execution

      expect { chat.tools }.to raise_error(ArgumentError, /Two tools are named run_code/)
    end
  end

  describe 'the run_code tool' do
    it 'lists only the languages the sandbox can run' do
      sandbox = FakeSandbox.new(missing: ['python3'])
      chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
      tool = chat.with_code_execution(languages: %i[ruby python shell]).tools[:run_code]

      expect(tool.languages).to eq(%i[ruby shell])
      expect(tool.parameters_schema.dig('properties', 'language', 'enum')).to eq(%w[ruby shell])
      expect(tool.description).to start_with('Runs Ruby or shell code in a sandbox')
      expect(tool.description).not_to include('Python')
    end

    it 'raises ConfigurationError when the sandbox runs none of the languages' do
      sandbox = FakeSandbox.new(missing: ['python3'])
      chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
      tool = chat.with_code_execution(languages: [:python]).tools[:run_code]

      expect { tool.languages }.to raise_error(RubyLLM::ConfigurationError, /cannot run python/)
    end

    it "describes the sandbox's timeout and network, and the declared packages" do
      online = FakeSandbox.new(timeout: 30, network: { allow: ['pypi.org'] })
      tool = chat.with_code_execution(sandbox: online, gems: %w[prawn], python: %w[pandas]).tools[:run_code]

      expect(tool.description).to include('Stops after 30 seconds.')
      expect(tool.description).to include('Can reach only pypi.org.')
      expect(tool.description).to include("Ruby #{RUBY_VERSION} has these gems: prawn.")
      expect(tool.description).to include('Python has these packages: pandas.')
      expect(chat.with_code_execution(sandbox: FakeSandbox.new(network: true)).tools[:run_code].description)
        .to include('Can reach the network.')
      expect(chat.with_code_execution.tools[:run_code].description).to include('No network access.')
    end

    it 'runs the code in a fresh run directory with only the Ruby installation readable' do
      sandbox = FakeSandbox.new(timeout: 12)
      chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
      result = chat.with_code_execution.tools[:run_code].call(language: 'ruby', code: 'puts 1 + 1')
      run = sandbox.code_runs.last

      expect(report(result)).to eq('exit_code' => 0, 'stdout' => '', 'stderr' => '')
      expect(run[:command]).to eq(['ruby', File.join(File.dirname(run[:directory]), 'source', 'main.rb')])
      expect(run[:readable]).to include(RbConfig::CONFIG['prefix'])
      expect(run[:readable]).not_to include(Dir.pwd)
      expect(run[:denied]).to eq(RubyLLM::CodeExecution::RubyInstallation.current.denied)
      scratch = File.dirname(run[:directory])
      expect(run[:writable]).to eq([run[:directory], File.join(scratch, 'home'), File.join(scratch, 'tmp')])
      expect(run[:network]).to be_nil
      expect(run[:timeout]).to eq(12)
      expect(run[:env]).to include('HOME' => File.join(scratch, 'home'), 'TMPDIR' => File.join(scratch, 'tmp'),
                                   'XDG_CACHE_HOME' => File.join(scratch, 'home', '.cache'))
      expect(run[:env].keys).to contain_exactly('PATH', 'HOME', 'XDG_CACHE_HOME', 'TMPDIR', 'LANG', 'RUN_DIR')
      expect(run[:env]['RUN_DIR']).to eq(run[:directory])
      expect(run[:env]['PATH']).to start_with(RbConfig::CONFIG['bindir'])
      expect(File.exist?(run[:directory])).to be(false)
    end

    it 'writes the source to a file for each language' do
      sources = []
      sandbox = FakeSandbox.new do |run|
        sources << File.read(run[:command].last) if run[:command].last.to_s.include?('main.')
        FakeSandbox.result
      end
      chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
      chat.with_code_execution(languages: %i[ruby python shell])

      chat.tools[:run_code].call(language: 'python', code: 'print(1)')
      chat.tools[:run_code].call(language: 'shell', code: 'echo 1')

      expect(sandbox.code_runs.map { |run| run[:command].first }).to eq(%w[python3 sh])
      expect(sandbox.code_runs.map { |run| File.basename(run[:command].last) }).to eq(%w[main.py main.sh])
      expect(sources).to eq(['print(1)', 'echo 1'])
    end

    it 'stops runs after two minutes when the sandbox sets no timeout' do
      chat.with_code_execution
      run_code('puts 1')

      expect(sandbox.code_runs.last[:timeout]).to eq(120)
    end

    it 'emits code_execution.ruby_llm for each run' do
      events = []
      instrumenter = Object.new
      instrumenter.define_singleton_method(:instrument) do |name, payload, &block|
        result = block.call(payload)
        events << [name, payload.dup]
        result
      end
      sandbox = FakeSandbox.new do |run|
        File.write(File.join(run[:directory], 'out.txt'), 'x')
        FakeSandbox.result(exit_code: 3, blocked: ['evil.example:443'])
      end
      chat = RubyLLM.context do |config|
        config.sandbox = sandbox
        config.instrumenter = instrumenter
      end.chat(model: model_for(:openai), provider: :openai)
      chat.with_code_execution.tools[:run_code].call(language: 'shell', code: 'exit 3')

      name, payload = events.find { |event| event.first == 'code_execution.ruby_llm' }
      expect(name).to eq('code_execution.ruby_llm')
      expect(payload).to include(chat:, tool_name: 'run_code', language: :shell, sandbox: nil, timeout: 120,
                                 network: false,
                                 exit_code: 3, timed_out: false, blocked_hosts: ['evil.example:443'],
                                 files: ['out.txt'])
      expect(payload[:duration]).to be_a(Float)
    end

    it 'names the tool call a run answers in code_execution.ruby_llm' do
      payloads = []
      instrumenter = Object.new
      instrumenter.define_singleton_method(:instrument) do |name, payload, &block|
        result = block.call(payload)
        payloads << payload.dup if name == 'code_execution.ruby_llm'
        result
      end
      chat = RubyLLM.context do |config|
        config.sandbox = FakeSandbox.new { FakeSandbox.result }
        config.instrumenter = instrumenter
      end.chat(model: model_for(:openai), provider: :openai)
      tool_call = RubyLLM::ToolCall.new(id: 'call_42', name: 'run_code', arguments: {})

      chat.with_code_execution.tools[:run_code].call(language: 'shell', code: 'true', tool_call:)

      expect(payloads.sole).to include(tool_call_id: 'call_42')
    end

    it 'links mounted directories at fixed paths in the working directory' do
      Dir.mktmpdir do |skill|
        seen = nil
        sandbox = FakeSandbox.new do |run|
          link = File.join(run[:directory], 'skills', 'reports')
          seen = [File.symlink?(link), File.readlink(link), run[:readable].include?(skill)]
          FakeSandbox.result
        end
        tool = RubyLLM::CodeExecution.new(sandbox:, skills: -> { { 'skills/reports' => skill } })

        _, *files = Array(tool.call(language: 'ruby', code: 'x'))

        expect(seen).to eq([true, skill, true])
        expect(files).to be_empty
      end
    end

    it 'mounts directories read-only at the paths it is given' do
      Dir.mktmpdir do |templates|
        seen = nil
        sandbox = FakeSandbox.new do |run|
          link = File.join(run[:directory], 'templates', 'office')
          seen = [File.readlink(link), run[:readable].include?(File.realpath(templates)),
                  run[:writable].include?(File.realpath(templates))]
          FakeSandbox.result
        end
        chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
        chat.with_code_execution(mounts: { 'templates/office' => Pathname(templates) })

        _, *files = Array(chat.tools[:run_code].call(language: 'ruby', code: 'x'))

        expect(seen).to eq([File.realpath(templates), true, false])
        expect(files).to be_empty
        expect(chat.tools[:run_code].description)
          .to include('These folders are available read-only: ./templates/office.')
      end
    end

    it 'resolves a mounts Proc before each run' do
      Dir.mktmpdir do |first|
        Dir.mktmpdir do |second|
          current = first
          links = []
          sandbox = FakeSandbox.new do |run|
            links << File.readlink(File.join(run[:directory], 'templates'))
            FakeSandbox.result
          end
          chat = RubyLLM.context { |config| config.sandbox = sandbox }
                        .chat(model: model_for(:openai), provider: :openai)
          chat.with_code_execution(mounts: -> { { 'templates' => current } })

          chat.tools[:run_code].call(language: 'ruby', code: 'x')
          current = second
          chat.tools[:run_code].call(language: 'ruby', code: 'x')

          expect(links).to eq([File.realpath(first), File.realpath(second)])
        end
      end
    end

    it 'leaves mounts out of the description when there are none' do
      chat.with_code_execution(mounts: -> { {} })

      expect(chat.tools[:run_code].description).not_to include('read-only:')
    end

    it 'refuses mounts that are not directories or that take a reserved path' do
      expect { chat.with_code_execution(mounts: ['templates']) }.to raise_error(ArgumentError, /Hash or a Proc/)
      expect { chat.with_code_execution(mounts: { '/abs' => Dir.pwd }) }.to raise_error(ArgumentError, /not a path/)
      expect { chat.with_code_execution(mounts: { 'a/../b' => Dir.pwd }) }.to raise_error(ArgumentError, /not a path/)
      expect { chat.with_code_execution(mounts: { 'attachments' => Dir.pwd }) }
        .to raise_error(ArgumentError, /not a path/)
      expect { chat.with_code_execution(mounts: { 'skills/x' => Dir.pwd }) }.to raise_error(ArgumentError, /reserved/)

      chat.with_code_execution(mounts: -> { { 'templates' => File.join(Dir.pwd, 'missing') } })
      expect { run_code('puts 1') }.to raise_error(ArgumentError, /is not a directory/)
    end

    it 'refuses mounts outside the working directory' do
      tool = RubyLLM::CodeExecution.new(sandbox:, mounts: -> { { '../escape' => Dir.pwd } })

      expect { tool.call(language: 'ruby', code: 'x') }.to raise_error(ArgumentError, /not a path inside/)
    end

    it 'runs JavaScript with node and finds the npm packages next to the script' do
      Dir.mktmpdir do |project|
        node_modules = File.join(project, 'node_modules')
        FileUtils.mkdir_p(node_modules)
        seen = nil
        sandbox = FakeSandbox.new do |run|
          script = run[:command].last
          seen = [run[:command].first, File.basename(script),
                  File.readlink(File.join(File.dirname(script), 'node_modules')), run[:readable].include?(node_modules)]
          FakeSandbox.result
        end
        chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
        tool = chat.with_code_execution(node_modules:).tools[:run_code]

        tool.call(language: 'javascript', code: 'console.log(1)')

        expect(seen).to eq(['node', 'main.js', node_modules, true])
        expect(tool.parameters_schema.dig('properties', 'language', 'enum')).to eq(%w[ruby javascript shell])
      end
    end

    it 'refuses a language it was not given' do
      chat.with_code_execution(languages: [:ruby])

      expect(run_code('echo hi', language: 'shell')).to eq(error: 'Unsupported language shell. Use one of: ruby')
    end

    it 'returns the files the code writes as attachments' do
      png = File.binread(fixture_png)
      chat = RubyLLM.context { |config| config.sandbox = writing('chart.png' => png, 'data/out.csv' => "a,b\n1,2\n") }
                    .chat(model: model_for(:openai), provider: :openai).with_code_execution
      text, *files = chat.tools[:run_code].call(language: 'ruby', code: 'plot')

      expect(JSON.parse(text)['files']).to eq(%w[chart.png data/out.csv])
      expect(files.map(&:filename)).to eq(%w[chart.png data/out.csv])
      expect(files.first.mime_type).to eq('image/png')
      expect(files.first.content).to eq(png)
      expect(files.last.content).to eq("a,b\n1,2\n")
    end

    it 'leaves out symlinks, hidden files, and caches' do
      sandbox = FakeSandbox.new do |run|
        File.symlink('/etc/hostname', File.join(run[:directory], 'leak.txt'))
        FileUtils.mkdir_p(File.join(run[:directory], '__pycache__'))
        File.write(File.join(run[:directory], '__pycache__', 'x.pyc'), 'x')
        File.write(File.join(run[:directory], '.secret'), 'x')
        File.write(File.join(run[:directory], 'kept.txt'), 'kept')
        FakeSandbox.result
      end
      chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
      _, *files = chat.with_code_execution.tools[:run_code].call(language: 'ruby', code: 'x')

      expect(files.map(&:filename)).to eq(['kept.txt'])
    end

    it 'caps the number and size of returned files' do
      stub_const('RubyLLM::CodeExecution::MAX_FILES', 2)
      stub_const('RubyLLM::CodeExecution::MAX_FILE_SIZE', 10)
      files = { 'a.txt' => 'a', 'b.txt' => 'b', 'big.txt' => 'x' * 11, 'c.txt' => 'c' }
      chat = RubyLLM.context { |config| config.sandbox = writing(files) }
                    .chat(model: model_for(:openai), provider: :openai).with_code_execution
      text, *returned = chat.tools[:run_code].call(language: 'ruby', code: 'x')

      expect(returned.map(&:filename)).to eq(%w[a.txt b.txt])
      expect(JSON.parse(text)['skipped_files']).to eq(['big.txt (larger than 10 bytes)', 'c.txt (more than 2 files)'])
    end

    it 'copies the conversation files in read-only' do
      seen = nil
      sandbox = FakeSandbox.new do |run|
        inputs = File.join(run[:directory], 'attachments')
        seen = Dir.children(inputs).sort.to_h { |name| [name, File.binread(File.join(inputs, name))] }
        expect(run[:readable]).to include(inputs)
        FakeSandbox.result
      end
      chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
      chat.with_code_execution
      chat.add_message(role: :user, content: 'Look', attachments: [fixture_png])
      chat.add_message(role: :user, content: 'Data',
                       attachments: [RubyLLM::Attachment.new(StringIO.new('1,2'), filename: '../../data.csv')])

      chat.tools[:run_code].call(language: 'ruby', code: 'x')

      expect(seen.keys).to eq(%w[data.csv ruby.png])
      expect(seen['data.csv']).to eq('1,2')
    end

    it 'reports a timeout' do
      sandbox = FakeSandbox.new { FakeSandbox.result(exit_code: nil, timed_out: true, stdout: 'partial') }
      chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
      result = chat.with_code_execution.tools[:run_code].call(language: 'ruby', code: 'sleep')

      expect(report(result)).to eq('stdout' => 'partial', 'stderr' => '',
                                   'error' => 'The code ran past its time limit and was stopped')
    end

    it 'reports blocked hosts' do
      sandbox = FakeSandbox.new { FakeSandbox.result(exit_code: 1, blocked: ['evil.example:443']) }
      chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
      result = chat.with_code_execution.tools[:run_code].call(language: 'ruby', code: 'x')

      expect(report(result)['blocked_hosts']).to eq(['evil.example:443'])
    end

    it 'keeps the start and end of long output' do
      stub_const('RubyLLM::CodeExecution::MAX_OUTPUT', 10)
      sandbox = FakeSandbox.new { FakeSandbox.result(stdout: "abcde#{'x' * 100}vwxyz", stderr: "\xFF".b) }
      chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model: model_for(:openai), provider: :openai)
      output = report(chat.with_code_execution.tools[:run_code].call(language: 'ruby', code: 'x'))

      expect(output['stdout']).to eq("abcde\n[100 characters omitted]\nvwxyz")
      expect(output['stderr']).to eq([0xFFFD].pack('U'))
    end
  end

  describe 'the conversation loop' do
    it 'attaches the files to the tool result and shows the model only what it can read' do
      png = File.binread(fixture_png)
      chat = RubyLLM.context { |config| config.sandbox = writing('chart.png' => png, 'report.zip' => 'PK') }
                    .chat(model: model_for(:anthropic), provider: :anthropic).with_code_execution
      call = tool_call(code: 'plot')
      allow(chat.provider).to receive(:complete).and_return(
        RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }),
        RubyLLM::Message.new(role: :assistant, content: 'Here is your chart.')
      )

      chat.ask('Plot it')
      result = chat.messages.find(&:tool_result?)
      rendered = chat.render[:messages].find { |message| message[:content].to_json.include?('tool_result') }

      expect(result.attachments.map(&:filename)).to eq(%w[chart.png report.zip])
      expect(rendered[:content].first[:content].map { |block| block[:type] }).to eq(%w[text image text])
      expect(rendered.to_json).to include('report.zip (application/zip, 2 bytes) is not shown here')
      expect(rendered.to_json).to include('attachments/report.zip')
    end

    it 'describes large text files instead of sending them to the model' do
      stub_const('RubyLLM::CodeExecution::MAX_MODEL_TEXT', 4)
      chat = RubyLLM.context { |config| config.sandbox = writing('rows.csv' => "a,b\n1,2\n") }
                    .chat(model: model_for(:anthropic), provider: :anthropic).with_code_execution
      call = tool_call(code: 'x')
      chat.add_message(role: :user, content: 'Go')
      chat.add_message(role: :assistant, content: '', tool_calls: { call.id => call })
      text, *files = chat.tools[:run_code].call(language: 'ruby', code: 'x')
      chat.add_message(role: :tool, content: text, attachments: files, tool_call_id: call.id)

      expect(chat.render.to_json).to include('rows.csv (text/csv, 8 bytes) is not shown here')
      expect(chat.render.to_json).not_to include('1,2')
    end

    it 'describes uploads the provider cannot read so code can open them' do
      chat.with_code_execution
      chat.add_message(role: :user, content: 'Unzip this',
                       attachments: [RubyLLM::Attachment.new(StringIO.new('PK'), filename: 'archive.zip')])

      expect(chat.render.to_json).to include('archive.zip (application/zip, 2 bytes) is not shown here')
    end

    it 'keeps the unsupported attachment error without code execution' do
      chat.add_message(role: :user, content: 'Unzip this',
                       attachments: [RubyLLM::Attachment.new(StringIO.new('PK'), filename: 'archive.zip')])

      expect { chat.render }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end
  end

  describe 'running code locally', :live do
    def mxc_supported
      require 'mxc'
      MXC.supported?
    rescue LoadError
      false
    end

    %i[openai anthropic].each do |provider|
      model = model_for(provider)

      it "#{provider}/#{model} runs code and returns the file it writes" do
        skip 'mxc cannot start a sandbox on this machine' unless mxc_supported

        chat = RubyLLM.context { |config| config.sandbox = MXC::Sandbox }
                      .chat(model:, provider:).with_code_execution(languages: [:ruby])
        response = chat.ask 'Use run_code once to compute the sum of the squares of 1 to 100, and write ' \
                            'squares.csv with the columns n and square for n from 1 to 10. Then tell me the sum.'
        result = chat.messages.find(&:tool_result?)

        expect(response.content).to include('338350').or include('338,350')
        expect(result.attachments.map(&:filename)).to include('squares.csv')
        expect(result.attachments.find { |file| file.filename == 'squares.csv' }.content).to include('10,100')
      end
    end
  end
end
