# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Sandbox::MXC do
  include_context 'with configured RubyLLM'

  def self.mxc_supported?
    require 'mxc'
    MXC.supported?
  rescue LoadError
    false
  end

  def self.network_policy_supported?
    mxc_supported? && MXC.supports?(:network_policy)
  end

  let(:sandbox) { RubyLLM::Sandbox.resolve(:mxc) }
  let(:cache_dir) { Dir.mktmpdir('ruby_llm-packages-spec') }
  let(:chat) do
    RubyLLM.context do |config|
      config.sandbox = :mxc
      config.package_cache_dir = cache_dir
    end.chat(model: model_for(:openai), provider: :openai)
  end

  before { skip 'mxc cannot start a sandbox on this machine' unless self.class.mxc_supported? }
  after { FileUtils.rm_rf(cache_dir) }

  def run_code(code, language: 'ruby', **options)
    chat.with_code_execution(**options).tools[:run_code].call(language:, code:)
  end

  def report(result)
    JSON.parse(Array(result).first)
  end

  it 'runs here' do
    expect(sandbox).to be_supported
    expect(sandbox.reason).to be_nil
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

  it 'cannot read the project or the home directory' do
    project = File.expand_path('../../../Gemfile', __dir__)
    home = Dir.home
    mounted = RbConfig::CONFIG['prefix'].delete_prefix(File.join(home, '')).split('/').first
    code = <<~RUBY
      puts((File.read(#{project.inspect}) rescue 'unreadable'))
      puts((Dir.children(#{home.inspect}) rescue []))
    RUBY
    output = report(run_code(code))

    expect(File.exist?(project)).to be(true)
    expect(output['stdout'].lines.first).to eq("unreadable\n")
    expect(output['stdout'].lines.drop(1).map(&:chomp) - [mounted]).to be_empty
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
    expect(output['stderr']).to match(/Read-only file system|Operation not permitted/)
  end

  it 'runs shell scripts' do
    expect(report(run_code('echo $((6 * 7))', language: 'shell'))['stdout']).to eq("42\n")
  end

  it 'runs Python when the sandbox has it' do
    tool = chat.with_code_execution(languages: %i[ruby python]).tools[:run_code]
    skip 'python3 is not available in the sandbox' unless tool.languages.include?(:python)

    expect(report(tool.call(language: 'python', code: 'print(6 * 7)'))['stdout']).to eq("42\n")
  end

  it 'stops code that runs past its timeout' do
    output = report(run_code('sleep 5', language: 'shell', timeout: 1))

    expect(output['error']).to eq('The code ran past the 1-second limit and was stopped')
  end

  it 'runs LibreOffice, Poppler, and fontconfig with a writable home and cache' do
    installed = %w[soffice pdftoppm fc-list].all? { |tool| system('which', tool, out: File::NULL) }
    skip 'LibreOffice and Poppler are not installed' unless installed

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

  it 'reads extra paths and mounted directories it is given' do
    Dir.mktmpdir do |skill|
      File.write(File.join(skill, 'hello.rb'), 'puts "from the skill"')
      tool = RubyLLM::CodeExecution.new(sandbox:, skills: -> { { 'skills/hello' => skill } })

      expect(report(tool.call(language: 'ruby', code: "load 'skills/hello/hello.rb'"))['stdout'])
        .to eq("from the skill\n")
      expect(report(run_code("puts File.read(#{File.join(skill, 'hello.rb').inspect})", readable: [skill]))['stdout'])
        .to eq("puts \"from the skill\"\n")
    end
  end

  it 'installs declared gems once, with only RubyGems reachable' do
    skip 'host allow-lists are not available on this machine' unless self.class.network_policy_supported?

    output = report(run_code("require 'rainbow'; puts Gem.loaded_specs.fetch('rainbow').version", gems: %w[rainbow]))

    expect(output['exit_code']).to eq(0)
    expect(Dir.glob(File.join(cache_dir, 'ruby-*.ready')).size).to eq(1)
  end
end
