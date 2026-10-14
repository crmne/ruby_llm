# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe RubyLLM::Sandbox do
  describe '.resolve' do
    it 'returns nil when no sandbox is configured' do
      expect(described_class.resolve(nil)).to be_nil
    end

    it 'builds the mxc sandbox for :mxc' do
      expect(described_class.resolve(:mxc)).to be_a(RubyLLM::Sandbox::MXC)
      expect(described_class.resolve('mxc')).to be(described_class.resolve(:mxc))
    end

    it 'returns any object answering supported? and run' do
      sandbox = FakeSandbox.new

      expect(described_class.resolve(sandbox)).to be(sandbox)
    end

    it 'raises ConfigurationError for anything else' do
      expect { described_class.resolve(:docker) }
        .to raise_error(RubyLLM::ConfigurationError, /must be :mxc or an object answering supported\? and run/)
    end

    it 'names the gem when mxc is missing' do
      described_class.instance_variable_set(:@mxc, nil)
      allow(described_class).to receive(:require).with('mxc').and_raise(LoadError)

      expect { described_class.resolve(:mxc) }.to raise_error(RubyLLM::ConfigurationError, /Add `gem "mxc"`/)
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
  end

  describe 'booting a Rails app' do
    def boot(supported:)
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
      stdout, = Open3.capture3(RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-e', script)
      stdout
    end

    it 'fails when the configured sandbox cannot run' do
      expect(boot(supported: false)).to eq('The configured sandbox cannot run on this machine. Install bubblewrap.')
    end

    it 'boots when it can' do
      expect(boot(supported: true)).to eq('booted')
    end
  end
end
