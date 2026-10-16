# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::CodeExecution::Packages do
  let(:cache_dir) { Dir.mktmpdir('ruby_llm-packages-spec') }
  let(:sandbox) { FakeSandbox.new { |run| install(run) } }

  after { FileUtils.rm_rf(cache_dir) }

  def install(run)
    return FakeSandbox.result(stdout: "3.14.0\n") if run[:command].include?('import sys; print(sys.version)')

    FakeSandbox.result
  end

  def packages(**)
    described_class.new(sandbox:, cache_dir:, **)
  end

  def ruby_gems(directory = cache_dir)
    RubyLLM::CodeExecution::RubyInstallation.current.ruby_gems(directory)
  end

  def gem_path(*directories)
    directories.join(File::PATH_SEPARATOR)
  end

  describe 'declared gems' do
    it 'installs them in the sandbox with only RubyGems reachable' do
      directory = packages(gems: %w[rubyzip prawn]).gem_home
      run = sandbox.runs.last

      expect(File.dirname(directory)).to eq(cache_dir)
      expect(run[:command]).to eq(['ruby', '-S', 'gem', 'install', '--no-document', '--install-dir', directory,
                                   '--bindir', File.join(directory, 'bin'), 'rubyzip', 'prawn'])
      expect(run[:network]).to eq(allow: %w[rubygems.org *.rubygems.org])
      expect(run[:writable]).to include(directory)
      expect(run[:env]).to include('GEM_HOME' => directory, 'GEM_PATH' => gem_path(directory, ruby_gems))
      expect(run[:readable]).to include(RbConfig::CONFIG['prefix'], ruby_gems)
      expect(File.exist?("#{directory}.ready")).to be(true)
    end

    it 'lets the installer read the resolver configuration' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/etc/resolv.conf').and_return(true)
      allow(File).to receive(:realpath).and_call_original
      allow(File).to receive(:realpath).with('/etc/resolv.conf').and_return('/private/var/run/resolv.conf')
      packages(gems: %w[prawn]).gem_home

      expect(sandbox.runs.last[:readable]).to include('/etc/resolv.conf', '/private/var/run/resolv.conf')
    end

    it "hides the application's gems from the installer" do
      packages(gems: %w[prawn]).gem_home

      expect(sandbox.runs.last[:denied]).to eq(RubyLLM::CodeExecution::RubyInstallation.current.denied)
    end

    it 'mounts the gems read-only and puts them on the gem path' do
      gems = packages(gems: %w[prawn])
      directory = gems.gem_home
      env = gems.env('/home')

      expect(gems.readable).to include(directory, ruby_gems)
      expect(env['GEM_PATH']).to eq(gem_path(directory, ruby_gems))
      expect(env['GEM_HOME']).to eq(directory)
      expect(env['GEM_PATH'].split(File::PATH_SEPARATOR)).not_to include(Gem.default_dir)
      expect(env['PATH']).to start_with(File.join(directory, 'bin'))
      expect(env).not_to have_key('VIRTUAL_ENV')
    end

    it 'installs each set once, whatever the order' do
      first = packages(gems: %w[prawn rubyzip]).gem_home
      second = packages(gems: %w[rubyzip prawn]).gem_home

      expect(second).to eq(first)
      expect(sandbox.runs.count { |run| run[:command].include?('install') }).to eq(1)
    end

    it 'keys the set by the Ruby that runs it' do
      first = packages(gems: %w[prawn]).gem_home
      stub_const('RUBY_VERSION', '9.9.9')

      expect(packages(gems: %w[prawn]).gem_home).not_to eq(first)
    end

    it 'installs once when processes race for the same set' do
      sandbox = FakeSandbox.new do
        sleep 0.05
        FakeSandbox.result
      end
      directories = Array.new(4) do
        Thread.new { described_class.new(sandbox:, cache_dir:, gems: %w[prawn]).gem_home }
      end.map(&:value)

      expect(directories.uniq.size).to eq(1)
      expect(sandbox.runs.size).to eq(1)
    end

    it 'raises with the installer output and leaves nothing to reuse' do
      sandbox = FakeSandbox.new do
        FakeSandbox.result(exit_code: 1, stderr: 'ERROR: could not find gem nope', blocked: ['evil.example:443'])
      end

      expect { described_class.new(sandbox:, cache_dir:, gems: %w[nope]).gem_home }
        .to raise_error(RubyLLM::Error, /Could not install gems nope: ERROR: could not find gem nope \(blocked: evil/)
      expect(Dir.glob(File.join(cache_dir, 'ruby-*.ready'))).to be_empty
    end

    it 'reports an install that ran out of time' do
      sandbox = FakeSandbox.new { FakeSandbox.result(exit_code: nil, timed_out: true) }

      expect { described_class.new(sandbox:, cache_dir:, gems: %w[prawn]).gem_home }
        .to raise_error(RubyLLM::Error, /timed out after 600 seconds/)
    end

    it 'raises ConfigurationError without a cache directory' do
      expect { described_class.new(sandbox:, cache_dir: nil, gems: %w[prawn]).gem_home }
        .to raise_error(RubyLLM::ConfigurationError, /package_cache_dir/)
    end
  end

  describe 'prebuilt environments' do
    it 'mounts a prebuilt GEM_HOME without installing' do
      Dir.mktmpdir do |home|
        FileUtils.mkdir_p(File.join(home, 'specifications'))
        File.write(File.join(home, 'specifications', 'prawn-2.5.0.gemspec'), '')
        File.write(File.join(home, 'specifications', 'pdf-core-0.10.0.gemspec'), '')
        gems = packages(gem_home: home)

        expect(gems.gem_home).to eq(home)
        expect(gems.readable).to include(home, ruby_gems)
        expect(gems.env('/home')).to include('GEM_HOME' => home, 'GEM_PATH' => gem_path(home, ruby_gems))
        expect(gems.gem_names).to eq(%w[pdf-core prawn])
        expect(sandbox.runs).to be_empty
      end
    end

    it 'names platform gems without their version and platform' do
      Dir.mktmpdir do |home|
        FileUtils.mkdir_p(File.join(home, 'specifications'))
        %w[
          rack-3.1.8 net-http2-0.18.5 ffi-1.17.0-x86_64-linux-gnu google-protobuf-4.29.3-x86_64-linux
          nokogiri-1.18.10-x86_64-linux-gnu nokogiri-1.18.10-java
        ].each { |name| File.write(File.join(home, 'specifications', "#{name}.gemspec"), '') }

        expect(packages(gem_home: home).gem_names).to eq(%w[ffi google-protobuf net-http2 nokogiri rack])
      end
    end

    it 'leaves the application gems off the gem path without a cache directory' do
      Dir.mktmpdir do |home|
        gems = described_class.new(sandbox:, cache_dir: nil, gem_home: home)
        path = gems.env('/home')['GEM_PATH'].split(File::PATH_SEPARATOR)

        expect(path.first).to eq(home)
        expect(path).not_to include(Gem.default_dir)
        expect(gems.readable).to include(path.last)
        expect(File.directory?(File.join(path.last, 'specifications'))).to be(true)
      end
    end

    it 'mounts a prebuilt virtualenv without installing' do
      Dir.mktmpdir do |venv|
        FileUtils.mkdir_p(File.join(venv, 'lib', 'python3.12', 'site-packages', 'pandas-2.2.3.dist-info'))
        python = packages(virtualenv: venv)

        expect(python.virtualenv).to eq(venv)
        expect(python.env('/home')).to include('VIRTUAL_ENV' => venv)
        expect(python.python_names).to eq(%w[pandas])
        expect(sandbox.runs).to be_empty
      end
    end

    it 'lists the declared packages without installing them' do
      expect(packages(gems: %w[prawn], python: %w[pandas]).then { |set| [set.gem_names, set.python_names] })
        .to eq([%w[prawn], %w[pandas]])
      expect(sandbox.runs).to be_empty
    end
  end

  describe 'declared Python packages' do
    it 'creates a virtualenv and installs into it with only PyPI reachable' do
      directory = packages(python: %w[pandas]).virtualenv
      venv, pip = sandbox.runs.last(2)

      expect(venv[:command]).to eq(['python3', '-m', 'venv', directory])
      expect(venv[:network]).to be(false)
      expect(pip[:command]).to eq([File.join(directory, 'bin', 'python'), '-m', 'pip', 'install', '--no-input',
                                   '--disable-pip-version-check', 'pandas'])
      expect(pip[:network]).to eq(allow: %w[pypi.org files.pythonhosted.org])
      expect(pip[:writable]).to include(directory)
    end

    it 'activates the virtualenv for runs' do
      python = packages(python: %w[pandas])
      directory = python.virtualenv
      env = python.env('/home')

      expect(env['VIRTUAL_ENV']).to eq(directory)
      expect(env['PATH']).to start_with(File.join(directory, 'bin'))
      expect(python.readable).to include(directory)
    end

    it 'keys the set by the Python in the sandbox' do
      first = packages(python: %w[pandas]).virtualenv
      other = FakeSandbox.new do |run|
        next FakeSandbox.result(stdout: "3.15.0\n") if run[:command].include?('import sys; print(sys.version)')

        FakeSandbox.result
      end

      expect(described_class.new(sandbox: other, cache_dir:, python: %w[pandas]).virtualenv).not_to eq(first)
    end
  end

  it 'gives runs without packages only the Ruby installation' do
    none = packages

    expect(none.readable).to all(start_with(RbConfig::CONFIG['prefix']).or(eq(Gem.default_dir)))
    expect(none.env('/home', '/tmp/run')).to include('HOME' => '/home', 'XDG_CACHE_HOME' => '/home/.cache',
                                                     'TMPDIR' => '/tmp/run')
    expect(none.env('/home').keys).to contain_exactly('PATH', 'HOME', 'XDG_CACHE_HOME', 'TMPDIR', 'LANG')
    expect(sandbox.runs).to be_empty
  end

  describe 'npm packages' do
    let(:node) do
      instance_double(RubyLLM::CodeExecution::NodeInstallation, prefix: '/opt/node', bin_dir: '/opt/node/bin',
                                                                version: 'v26.0.0', readable: ['/opt/node'])
    end

    it 'installs them in the sandbox with only the npm registry reachable and no install scripts' do
      node_modules = packages(npm: %w[pptxgenjs docx], node:).node_modules
      directory = File.dirname(node_modules)
      run = sandbox.runs.last

      expect(File.basename(node_modules)).to eq('node_modules')
      expect(File.dirname(directory)).to eq(cache_dir)
      expect(run[:command]).to eq(['npm', 'install', '--prefix', directory, '--ignore-scripts', '--no-audit',
                                   '--no-fund', '--no-update-notifier', 'pptxgenjs', 'docx'])
      expect(run[:network]).to eq(allow: %w[registry.npmjs.org])
      expect(run[:writable]).to include(directory)
      expect(run[:readable]).to include('/opt/node')
      expect(run[:env]['PATH'].split(File::PATH_SEPARATOR)).to include('/opt/node/bin')
    end

    it 'mounts Node and the packages read-only, with node on the PATH' do
      npm = packages(npm: %w[docx], node:)

      expect(npm.readable).to include('/opt/node', npm.node_modules)
      expect(npm.env('/home')['PATH'].split(File::PATH_SEPARATOR)).to include('/opt/node/bin')
      expect(npm.npm_names).to eq(%w[docx])
    end

    it 'installs again for another Node version' do
      first = packages(npm: %w[docx], node:).node_modules
      newer = instance_double(RubyLLM::CodeExecution::NodeInstallation, prefix: '/opt/node', bin_dir: '/opt/node/bin',
                                                                        version: 'v27.0.0', readable: ['/opt/node'])

      expect(packages(npm: %w[docx], node: newer).node_modules).not_to eq(first)
    end

    it 'mounts a prebuilt node_modules and lists what its package.json declares' do
      Dir.mktmpdir do |project|
        File.write(File.join(project, 'package.json'),
                   JSON.generate(dependencies: { 'pptxgenjs' => '^4', 'docx' => '^9' }))
        FileUtils.mkdir_p(File.join(project, 'node_modules', 'jszip'))
        npm = packages(node_modules: File.join(project, 'node_modules'), node:)

        expect(npm.node_modules).to eq(File.join(project, 'node_modules'))
        expect(npm.npm_names).to eq(%w[docx pptxgenjs])
        expect(sandbox.runs).to be_empty
      end
    end

    it 'raises without node on the PATH' do
      missing = instance_double(RubyLLM::CodeExecution::NodeInstallation, prefix: nil, bin_dir: nil, version: nil,
                                                                          readable: [])

      expect { packages(npm: %w[docx], node: missing).node_modules }.to raise_error(RubyLLM::Error, /node is not/)
    end
  end
end
