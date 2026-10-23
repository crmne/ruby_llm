# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Sandbox::MXC do
  include_context 'with configured RubyLLM'

  let(:sandbox) { RubyLLM::Sandbox.resolve(MXC::Sandbox) }
  let(:cache_dir) { Dir.mktmpdir('ruby_llm-packages-spec') }
  let(:chat) do
    RubyLLM.context do |config|
      config.sandbox = MXC::Sandbox
      config.package_cache_dir = cache_dir
    end.chat(model: model_for(:openai), provider: :openai)
  end

  before { skip 'mxc cannot start a sandbox on this machine' unless SandboxBackend.supported? }
  after { FileUtils.rm_rf(cache_dir) }

  def run_code(code, language: 'ruby', **options)
    chat.with_code_execution(**options).tools[:run_code].call(language:, code:)
  end

  def report(result)
    JSON.parse(Array(result).first)
  end

  it 'runs here, on the configured backend' do
    expect(sandbox).to be_supported
    expect(sandbox.reason).to be_nil
    expect(sandbox.backend).to eq(SandboxBackend.name)
  end

  it 'runs a command with the paths, directory, and environment it is given' do
    Dir.mktmpdir do |directory|
      result = sandbox.run('echo "$GREETING" > out.txt; cat out.txt',
                           writable: [directory], directory:, env: { 'GREETING' => 'hello' }, timeout: 10)

      expect(result.exit_code).to eq(0)
      expect(result.stdout).to eq("hello\n")
      expect(File.read(File.join(directory, 'out.txt'))).to eq("hello\n")
    end
  end

  it 'yields the output as it arrives, and still returns all of it' do
    chunks = []
    result = sandbox.run('echo one; sleep 0.3; echo two', timeout: 10) { |chunk| chunks << chunk.content }

    expect(chunks.join).to eq("one\ntwo\n")
    expect(chunks.size).to be >= 2
    expect(result.stdout).to eq("one\ntwo\n")
    expect(result.exit_code).to eq(0)
  end

  it 'reports the output of running code as progress' do
    reported = []
    tool = chat.with_code_execution.tools[:run_code]
    RubyLLM::Support::ProgressReporter.listen(->(progress) { reported << progress.message }) do
      tool.call(language: 'shell', code: 'echo first; sleep 0.4; echo second')
    end

    expect(reported).to eq(%w[first second])
  end

  it "runs Ruby with the app's Ruby, without the app's Bundler environment" do
    output = report(run_code('puts RUBY_VERSION, ENV.keys.grep(/BUNDLE|RUBYOPT|RUBYLIB|GEM_/).inspect'))

    expect(output['exit_code']).to eq(0)
    expect(output['stdout']).to eq("#{RUBY_VERSION}\n[]\n")
  end

  it 'loads the standard library and the bundled gems' do
    output = report(run_code("require 'json'; require 'csv'; puts CSV.generate_line([JSON.generate([1, 2])])"))

    expect(output['stdout']).to eq("\"[1,2]\"\n")
  end

  it "hides the application's gems" do
    rspec = Gem.loaded_specs.fetch('rspec-core').full_gem_path
    code = <<~RUBY
      begin
        require 'rspec/core'
        puts 'loaded'
      rescue LoadError
        puts 'missing'
      end
      begin
        puts Dir.children(#{rspec.inspect}).size
      rescue SystemCallError
        puts 0
      end
    RUBY

    expect(report(run_code(code))['stdout']).to eq("missing\n0\n")
    expect(Dir.children(rspec)).not_to be_empty
  end

  # Mounting Ruby, or hiding the application's gems, makes the sandbox create
  # empty directories down to those paths, so their first directory under home
  # shows by name. In CI the gems sit in the project's vendor/bundle.
  it 'cannot read the project or the home directory' do
    root = File.expand_path('../../..', __dir__)
    project = File.join(root, 'Gemfile')
    home = Dir.home
    shown = [RbConfig::CONFIG['prefix'], *Gem.loaded_specs.values.map(&:full_gem_path)]
            .filter_map { |path| path.delete_prefix(File.join(home, '')).split('/').first if path.start_with?(home) }
    code = <<~RUBY
      puts((File.read(#{project.inspect}) rescue 'unreadable'))
      puts((Dir.children(#{root.inspect}).include?('Gemfile') rescue false))
      puts((Dir.children(#{home.inspect}) rescue []))
    RUBY
    output = report(run_code(code)).fetch('stdout').lines.map(&:chomp)

    expect(File.exist?(project)).to be(true)
    expect(output.take(2)).to eq(%w[unreadable false])
    expect(output.drop(2) - shown).to be_empty
  end

  it 'has no network' do
    output = report(run_code('curl -sS --max-time 5 https://rubygems.org >/dev/null; echo $?', language: 'shell'))

    expect(output['stdout'].strip).not_to eq('0')
  end

  it 'returns the files the code writes, without following links' do
    text, *files = run_code(<<~RUBY)
      File.write('hello.txt', 'hi')
      File.symlink('/etc/hostname', 'host.txt')
    RUBY

    expect(JSON.parse(text)['files']).to eq(['hello.txt'])
    expect(files.map(&:content)).to eq(['hi'])
  end

  it 'gives the code read-only copies of the conversation files' do
    data = RubyLLM::Attachment.new(StringIO.new('1,2'), filename: 'data.csv')
    chat.add_message(role: :user, content: 'Data', attachments: [data])
    output = report(run_code("puts File.read('attachments/data.csv'); File.write('attachments/data.csv', 'x')"))

    expect(output['stdout']).to eq("1,2\n")
    expect(output['stderr']).to match(/Read-only file system|Operation not permitted|Permission denied/)
  end

  it 'runs shell scripts' do
    expect(report(run_code('echo $((6 * 7))', language: 'shell'))['stdout']).to eq("42\n")
  end

  it 'runs Python when the sandbox has it' do
    tool = chat.with_code_execution(languages: %i[ruby python]).tools[:run_code]
    skip 'python3 is not available in the sandbox' unless tool.languages.include?(:python)

    expect(report(tool.call(language: 'python', code: 'print(6 * 7)'))['stdout']).to eq("42\n")
  end

  it 'runs JavaScript when node is on the PATH, wherever it is installed' do
    tool = chat.with_code_execution(languages: %i[javascript]).tools[:run_code]
    skip 'node is not available' unless system('node', '-e', '0', out: File::NULL, err: File::NULL)

    output = report(tool.call(language: 'javascript', code: 'require("fs").writeFileSync("n.txt", String(6 * 7))'))

    expect(output).to include('exit_code' => 0, 'files' => ['n.txt'])
  end

  it 'stops code that runs past its timeout' do
    output = report(run_code('sleep 5', language: 'shell', sandbox: MXC::Sandbox.new(timeout: 1)))

    expect(output['error']).to eq('The code ran past its time limit and was stopped')
  end

  it 'runs LibreOffice, Poppler, and fontconfig with a writable home and cache' do
    installed = %w[soffice pdftoppm fc-list].all? { |tool| system('which', tool, out: File::NULL) }
    skip 'LibreOffice and Poppler are not installed' unless installed
    skip 'LibreOffice writes to /tmp, which Landlock leaves out' if SandboxBackend.landlock?

    text, *files = run_code(<<~SH, language: 'shell')
      printf 'Quarterly report' > report.txt
      soffice --headless --convert-to pdf report.txt >/dev/null 2>&1
      pdftoppm -png -r 50 report.pdf page
      rm report.txt
      fc-list | wc -l
    SH

    expect(JSON.parse(text)['stdout'].to_i).to be_positive
    expect(files.map(&:filename)).to eq(%w[page-1.png report.pdf])
  end

  it "reads the sandbox's readable paths and the mounted directories" do
    Dir.mktmpdir do |skill|
      File.write(File.join(skill, 'hello.rb'), 'puts "from the skill"')
      tool = RubyLLM::CodeExecution.new(sandbox:, skills: -> { { 'skills/hello' => skill } })

      expect(report(tool.call(language: 'ruby', code: "load 'skills/hello/hello.rb'"))['stdout'])
        .to eq("from the skill\n")
      readable = MXC::Sandbox.new(readable: [skill])
      expect(report(run_code("puts File.read(#{File.join(skill, 'hello.rb').inspect})", sandbox: readable))['stdout'])
        .to eq("puts \"from the skill\"\n")
    end
  end

  it 'installs declared gems once, with only RubyGems reachable' do
    skip 'host allow-lists are not available on this machine' unless SandboxBackend.network_policy?

    output = report(run_code("require 'rainbow'; puts Gem.loaded_specs.fetch('rainbow').version", gems: %w[rainbow]))

    expect(output['exit_code']).to eq(0)
    expect(Dir.glob(File.join(cache_dir, 'ruby-*.ready')).size).to eq(1)
  end

  it 'runs an approved escalation in the sandbox it names, starting in its directory' do
    Dir.mktmpdir do |project|
      project = File.realpath(project)
      stub_const('WorkspaceSandbox', Class.new(MXC::Sandbox))
      WorkspaceSandbox.directory project
      WorkspaceSandbox.writable project
      tool = chat.with_code_execution(escalate_to: [WorkspaceSandbox]).tools[:run_code]
      code = "File.write('notes.txt', 'kept'); File.write(File.join(ENV['RUN_DIR'], 'out.txt'), Dir.pwd)"
      call = RubyLLM::ToolCall.new(id: 'call_1', name: 'run_code',
                                   arguments: { 'language' => 'ruby', 'code' => code, 'sandbox' => 'workspace' })
      chat.add_message(role: :assistant, content: '', tool_calls: { call.id => call })

      default = report(run_code("File.write(#{File.join(project, 'x').inspect}, 'x') rescue puts 'refused'"))
      chat.approve('call_1')
      text, *files = tool.call(language: 'ruby', code:, sandbox: 'workspace', tool_call: call)

      expect(default['stdout']).to eq("refused\n")
      expect(JSON.parse(text)['exit_code']).to eq(0)
      expect(File.read(File.join(project, 'notes.txt'))).to eq('kept')
      expect(files.map { |file| [file.filename, file.content] }).to eq([['out.txt', project]])
    end
  end
end
