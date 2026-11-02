# frozen_string_literal: true

require 'spec_helper'
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

    it 'stops the processes it started' do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'pid')
        stdio = described_class.new(['sh', '-c', "sleep 30 </dev/null & echo $! > #{path}; wait"])
        stdio.send(:start)
        sleep 0.05 until File.size?(path)

        stdio.close

        expect(stopped?(File.read(path).to_i)).to be(true)
      end
    end

    it 'signals only the server where the platform has no process groups' do
      allow(Gem).to receive(:win_platform?).and_return(true)
      allow(Process).to receive(:kill).and_call_original
      stdio = described_class.new(%w[sleep 30])
      stdio.send(:start)
      pid = stdio.instance_variable_get(:@process).pid

      stdio.close

      expect(Process).to have_received(:kill).with('TERM', pid)
    end
  end
end
