# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe RubyLLM::Sandbox do
  describe '.resolve' do
    it 'returns nil when no sandbox is configured' do
      expect(described_class.resolve(nil)).to be_nil
    end

    it 'runs an MXC::Sandbox class or instance with a fresh copy of its policy for each run' do
      require 'mxc'
      stub_const('ReadOnlySandbox', Class.new(MXC::Sandbox) { timeout 30 })

      from_class = described_class.resolve(ReadOnlySandbox)
      from_instance = described_class.resolve(ReadOnlySandbox.new.with_network(allow: ['pypi.org']))

      expect(from_class).to be_a(RubyLLM::Sandbox::MXC)
      expect([from_class.timeout, from_class.network]).to eq([30, false])
      expect(from_instance.network).to eq(allow: ['pypi.org'])
      expect(from_instance.isolated.network).to be(false)
    end

    it 'runs an MXC::Sandbox on the configured backend unless it names its own' do
      skip 'mxc runs on MRI' unless RUBY_ENGINE == 'ruby'
      require 'mxc'
      stub_const('BubblewrapSandbox', Class.new(MXC::Sandbox) { backend :bubblewrap })
      allow(RubyLLM::Sandbox::MXC).to receive(:new).and_wrap_original do |original, *arguments, **options|
        original.call(*arguments, **options).tap { |runner| allow(runner).to receive(:linux?).and_return(true) }
      end

      expect(described_class.resolve(MXC::Sandbox).backend).to eq(RubyLLM.config.sandbox_backend)
      expect(described_class.resolve(MXC::Sandbox, backend: :bubblewrap).backend).to eq(:bubblewrap)
      expect(described_class.resolve(MXC::Sandbox, backend: :landlock).backend).to eq(:landlock)
      expect(described_class.resolve(MXC::Sandbox, backend: 'landlock').isolated.backend).to eq(:landlock)
      expect(described_class.resolve(BubblewrapSandbox, backend: :landlock).backend).to eq(:bubblewrap)
    end

    it 'raises ConfigurationError for an unknown backend' do
      skip 'mxc runs on MRI' unless RUBY_ENGINE == 'ruby'
      require 'mxc'

      expect { described_class.resolve(MXC::Sandbox, backend: :auto) }
        .to raise_error(RubyLLM::ConfigurationError, 'config.sandbox_backend is :bubblewrap or :landlock, got :auto')
    end

    it 'says how to allow user namespaces, or opt in to Landlock, when Bubblewrap cannot start' do
      skip 'mxc runs on MRI' unless RUBY_ENGINE == 'ruby'
      require 'mxc'
      blocked = MXC::Availability.new(
        backend: :bubblewrap, supported: false,
        reason: 'Bubblewrap could not start the sandbox: bwrap: setting up uid map: Permission denied',
        remediation: 'Unprivileged user namespaces are blocked.'
      )
      allow(MXC).to receive(:availability).and_return(blocked)
      runner = described_class.resolve(MXC::Sandbox.new(backend: :bubblewrap))

      expect(runner).not_to be_supported
      expect(runner.reason).to start_with('Bubblewrap could not start the sandbox: bwrap: setting up uid map')
      expect(runner.reason).to include('sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0',
                                       'Or set config.sandbox_backend = :landlock')
    end

    it 'returns any object answering supported? and run, and instantiates such a class' do
      sandbox = FakeSandbox.new

      expect(described_class.resolve(sandbox)).to be(sandbox)
      expect(described_class.resolve(FakeSandbox)).to be_a(FakeSandbox)
    end

    it 'raises ConfigurationError for anything else' do
      expect { described_class.resolve(:mxc) }
        .to raise_error(RubyLLM::ConfigurationError, /an MXC::Sandbox class or an object answering supported\? and run/)
    end
  end

  describe '.name_for' do
    it 'separates acronyms and digits from the following word' do
      expect(described_class.name_for('Admin::HTTP2ReadOnlySandbox')).to eq('http2_read_only')
      expect(described_class.name_for('HTTPSandbox')).to eq('http')
    end

    it 'names a sandbox after its class, without the Sandbox suffix' do
      stub_const('Admin::FullDiskSandbox', Class.new(FakeSandbox))

      expect(described_class.name_for(Admin::FullDiskSandbox)).to eq('full_disk')
      expect(described_class.name_for(Admin::FullDiskSandbox.new)).to eq('full_disk')
      expect { described_class.name_for(Class.new(FakeSandbox)) }.to raise_error(ArgumentError, /Name the sandbox/)
    end
  end

  describe '.verify' do
    it 'passes without a sandbox or with one that runs here' do
      expect { described_class.verify(nil) }.not_to raise_error
      expect { described_class.verify(FakeSandbox.new) }.not_to raise_error
    end

    it "raises ConfigurationError with the sandbox's reason" do
      sandbox = FakeSandbox.new(supported: false)
      def sandbox.reason = 'Install bubblewrap.'

      expect { described_class.verify(sandbox) }
        .to raise_error(RubyLLM::ConfigurationError,
                        'The configured sandbox cannot run on this machine. Install bubblewrap.')
    end
  end

  describe 'RubyLLM.sandbox' do
    around do |example|
      original = RubyLLM.config.sandbox
      example.run
    ensure
      RubyLLM.config.sandbox = original
    end

    it 'returns the configured sandbox' do
      sandbox = FakeSandbox.new
      RubyLLM.config.sandbox = sandbox

      expect(RubyLLM.sandbox).to be(sandbox)
    end

    it 'returns nil by default' do
      RubyLLM.config.sandbox = nil

      expect(RubyLLM.sandbox).to be_nil
    end

    it 'runs on the configured backend' do
      skip 'mxc runs on MRI' unless RUBY_ENGINE == 'ruby'
      require 'mxc'
      original = RubyLLM.config.sandbox_backend
      RubyLLM.config.sandbox = MXC::Sandbox.new(backend: :auto)
      RubyLLM.config.sandbox_backend = :landlock
      chat = RubyLLM.context do |config|
        config.openai_api_key = 'test'
        config.sandbox_backend = :bubblewrap
      end.chat(model: model_for(:openai), provider: :openai)

      expect(RubyLLM.sandbox.backend).to eq(RUBY_PLATFORM.include?('linux') ? :landlock : :auto)
      expect(chat.with_code_execution.tools[:run_code].sandbox.backend)
        .to eq(RUBY_PLATFORM.include?('linux') ? :bubblewrap : :auto)
    ensure
      RubyLLM.config.sandbox_backend = original
    end
  end

  describe 'booting a Rails app' do
    def boot(supported:, env: {})
      script = <<~RUBY
        ENV['RAILS_ENV'] = 'test'
        require 'bundler/setup'
        require 'ruby_llm'
        require #{File.expand_path('../support/fake_sandbox', __dir__).inspect}
        sandbox = FakeSandbox.new(supported: #{supported})
        def sandbox.reason = 'Install bubblewrap.'
        RubyLLM.config.sandbox = sandbox
        require #{File.expand_path('../dummy/config/application', __dir__).inspect}
        require 'ruby_llm/railtie'
        begin
          Rails.application.initialize!
          print 'booted'
        rescue RubyLLM::ConfigurationError => e
          print e.message
        end
      RUBY
      stdout, = Open3.capture3(env, RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-e', script)
      stdout
    end

    it 'fails when the configured sandbox cannot run' do
      expect(boot(supported: false)).to eq('The configured sandbox cannot run on this machine. Install bubblewrap.')
    end

    it 'skips the check in build-time boots such as assets:precompile' do
      expect(boot(supported: false, env: { 'SECRET_KEY_BASE_DUMMY' => '1' })).to eq('booted')
    end

    it 'boots when it can' do
      expect(boot(supported: true)).to eq('booted')
    end
  end
end
