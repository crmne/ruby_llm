# frozen_string_literal: true

require 'spec_helper'
require 'timeout'
require 'tmpdir'

RSpec.describe RubyLLM::MCP::Stdio do
  let(:server) do
    <<~RUBY
      require 'json'
      $stdout.sync = true
      while (line = $stdin.gets)
        puts JSON.generate(id: JSON.parse(line)['id'], env: ENV.to_h, directory: Dir.pwd)
      end
    RUBY
  end

  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  def child(command = RbConfig.ruby, **options)
    stdio = described_class.new([command, '-e', server], **options)
    stdio.request({ id: 1, method: 'probe' })
  ensure
    stdio.close
  end

  it 'keeps the application environment from the server' do
    ENV['FAKE_PROVIDER_API_KEY'] = 'sk-parent'
    ENV['BUNDLE_GEMFILE'] = '/app/Gemfile'

    expect(child['env'].keys).not_to include('FAKE_PROVIDER_API_KEY', 'BUNDLE_GEMFILE')
  end

  it 'passes on the variables a server needs to start' do
    inherited = %w[
      GEM_HOME GEM_PATH HOME LANG LC_ALL LC_CTYPE LOGNAME SHELL TERM TMPDIR USER
      APPDATA COMSPEC HOMEDRIVE HOMEPATH LOCALAPPDATA PATHEXT PROCESSOR_ARCHITECTURE
      PROGRAMDATA PROGRAMFILES PROGRAMFILES(X86) PROGRAMW6432 SYSTEMDRIVE SYSTEMROOT
      TEMP TMP USERNAME USERPROFILE WINDIR
    ].to_h { |name| [name, "inherited-#{name}"] }
    ENV.update(inherited)

    expect(child['env']).to include(inherited)
  end

  it 'finds the command on the inherited PATH' do
    ENV['PATH'] = File.dirname(RbConfig.ruby)

    expect(child(File.basename(RbConfig.ruby))['env']).to include('PATH' => ENV.fetch('PATH'))
  end

  it 'leaves out inherited variables the application has not set' do
    ENV.delete('LC_ALL')

    expect(child['env']).not_to have_key('LC_ALL')
  end

  it 'prefers env over the inherited value' do
    ENV['TERM'] = 'inherited'

    expect(child(env: { TERM: 'explicit' })['env']).to include('TERM' => 'explicit')
  end

  it 'prefers env over a parent variable it does not inherit' do
    ENV['FAKE_PROVIDER_API_KEY'] = 'sk-parent'

    expect(child(env: { FAKE_PROVIDER_API_KEY: 'sk-explicit' })['env'])
      .to include('FAKE_PROVIDER_API_KEY' => 'sk-explicit')
  end

  it 'still starts the server in its directory' do
    Dir.mktmpdir do |directory|
      expect(child(directory:)['directory']).to eq(File.realpath(directory))
    end
  end

  context 'with an env value that raises an I/O error' do
    let(:stdio) { described_class.new([RbConfig.ruby, '-e', server], env: -> { raise IOError, 'token file closed' }) }

    after { stdio.close }

    it 'raises it from a request instead of reporting that the server exited' do
      expect { stdio.request({ id: 1, method: 'probe' }) }.to raise_error(IOError, 'token file closed')
    end

    it 'raises it from a subscription instead of reporting that the server exited' do
      expect { stdio.listen({ id: 1, method: 'subscriptions/listen' }) { nil } }
        .to raise_error(IOError, 'token file closed')
    end
  end

  describe 'stopping a server that outlives its stdin' do
    before { stub_const("#{described_class}::SHUTDOWN_GRACE", 0.2) }

    def stopped?(pid)
      40.times do
        state = `ps -o stat= -p #{pid}`.strip
        return true if state.empty? || state.start_with?('Z')

        sleep 0.05
      end
      false
    end

    def stop_server(script)
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'pid')
        stdio = described_class.new(['sh', '-c', script, 'sh', path])
        stdio.send(:start)
        begin
          Timeout.timeout(5) { sleep 0.05 until File.size?(path) }
        ensure
          stdio.close
        end
        yield path
      end
    end

    def stopped_child(script)
      stop_server(script) { |path| stopped?(File.read(path).to_i) }
    end

    it 'lets a server finish after its stdin closes', skip: Gem.win_platform? do
      script = 'echo $$ > "$1"; cat > /dev/null; sleep 0.05; touch "$1.done"'

      stop_server(script) { |path| expect(File).to exist("#{path}.done") }
    end

    it 'lets a server finish after the request to stop', skip: Gem.win_platform? do
      script = 'trap "sleep 0.05; touch \"\$1.done\"; exit" TERM; echo $$ > "$1"; sleep 30 </dev/null & wait'

      stop_server(script) { |path| expect(File).to exist("#{path}.done") }
    end

    it 'stops a child while the server waits for it', skip: Gem.win_platform? do
      expect(stopped_child('sleep 30 </dev/null & echo $! > "$1"; wait')).to be(true)
    end

    it 'stops a child the server leaves behind on exit', skip: Gem.win_platform? do
      expect(stopped_child('sleep 30 </dev/null & echo $! > "$1"; cat > /dev/null')).to be(true)
    end

    it 'stops a child that ignores the request to stop', skip: Gem.win_platform? do
      script = '(trap "" TERM; exec sleep 30 </dev/null) & echo $! > "$1"; wait'

      expect(stopped_child(script)).to be(true)
    end

    it 'signals only the server where the platform has no process groups' do
      allow(Gem).to receive(:win_platform?).and_return(true)
      allow(Process).to receive(:kill).and_call_original
      stdio = described_class.new([RbConfig.ruby, '-e', 'sleep 30'])
      stdio.send(:start)
      pid = stdio.instance_variable_get(:@process).pid

      stdio.close

      expect(Process).to have_received(:kill).with('TERM', pid)
    end
  end
end
