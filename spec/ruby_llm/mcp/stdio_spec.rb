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
end
