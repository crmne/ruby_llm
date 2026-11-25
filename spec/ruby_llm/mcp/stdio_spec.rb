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

  it 'reports a server that is not running when listening to its session' do
    stdio = described_class.new([RbConfig.ruby, '-e', server])

    expect { stdio.listen(nil) { nil } }.to raise_error(RubyLLM::MCP::Stdio::Unavailable, /exited/)
  end

  describe 'a request larger than the pipe buffer' do
    let(:message) { { id: 1, method: 'probe', text: 'x' * 500_000 } }

    def request(script, timeout:)
      stdio = described_class.new([RbConfig.ruby, '-rjson', '-e', script], timeout:)
      Timeout.timeout(20) { stdio.request(message) }
    ensure
      stdio.close
    end

    it 'times out when the server stops reading' do
      expect { request('sleep', timeout: 0.5) }.to raise_error(described_class::Unavailable, /in time/)
    end

    it 'stops when the chat is cancelled' do
      allow(RubyLLM::Support::Cancellation).to receive(:check).and_raise(RubyLLM::CancelledError)

      expect { request('sleep', timeout: 30) }.to raise_error(RubyLLM::CancelledError)
    end

    it 'reaches a server that writes more than the pipe buffer before it reads on' do
      script = <<~RUBY
        $stdin.readpartial(1)
        puts JSON.generate(id: 0, text: 'y' * 500_000)
        $stdin.gets
        puts JSON.generate(id: 1, read: true)
        $stdout.flush
        $stdin.gets
      RUBY

      expect(request(script, timeout: 10)).to include('read' => true)
    end

    it 'starts the server again for the next request' do
      Dir.mktmpdir do |directory|
        marker = File.join(directory, 'stuck')
        script = "unless File.exist?('#{marker}')\nFile.write('#{marker}', '')\nsleep\nend\n#{server}"
        stdio = described_class.new([RbConfig.ruby, '-e', script], timeout: 1)

        expect { Timeout.timeout(20) { stdio.request(message) } }.to raise_error(described_class::Unavailable)
        expect(stdio.request({ id: 2, method: 'probe' }, timeout: 5)['id']).to eq(2)
      ensure
        stdio.close
      end
    end
  end

  it 'keeps the application environment from the server' do
    parent = %w[
      FAKE_PROVIDER_API_KEY BUNDLE_GEMFILE BUNDLE_PATH RAILS_ENV SECRET_KEY_BASE NODE_EXTRA_CA_CERTS
      HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy
    ]
    parent.each { |name| ENV[name] = "parent-#{name}" }

    expect(child['env'].keys & parent).to be_empty
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
