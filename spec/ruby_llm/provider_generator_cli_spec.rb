# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'
require 'stringio'
require 'tmpdir'

RSpec.describe RubyLLM::ProviderGeneratorCLI do
  let(:dir) { File.realpath(Dir.mktmpdir('ruby_llm_provider_cli')) }

  after do
    FileUtils.rm_rf(dir)
  end

  describe '.run' do
    it 'generates a provider gem from CLI arguments' do
      out = StringIO.new
      err = StringIO.new

      status = described_class.run(
        [
          'provider-gem',
          'AcmeAI',
          '--destination',
          dir,
          '--api-base',
          'https://api.acme.test/v1',
          '--skip-bundle'
        ],
        out: out,
        err: err
      )

      expect(status).to eq(0)
      expect(err.string).to be_empty
      expect(out.string).to include('create  .gitignore')
      expect(out.string).to include('run  git init')
      expect(File.exist?(File.join(dir, 'lib/ruby_llm/providers/acme_ai.rb'))).to be(true)
      expect(Dir.exist?(File.join(dir, 'lib/ruby_llm/acme_ai'))).to be(false)
      expect(Dir.exist?(File.join(dir, '.git'))).to be(true)
      gemspec = File.read(File.join(dir, 'ruby_llm-providers-acme-ai.gemspec'))
      workflow = File.read(File.join(dir, '.github/workflows/ci.yml'))
      rubocop = File.read(File.join(dir, '.rubocop.yml'))
      expect(gemspec).to include("spec.required_ruby_version = '>= 3.1'")
      expect(workflow).to include('ruby-version: ["3.1", "3.2", "3.3", "3.4", "4.0"]')
      expect(rubocop).to include('TargetRubyVersion: 3.1')
    end

    it 'prints help for unknown commands' do
      out = StringIO.new
      err = StringIO.new

      status = described_class.run(['unknown'], out: out, err: err)

      expect(status).to eq(1)
      expect(err.string).to include('Unknown command: unknown')
      expect(err.string).to include('ruby_llm provider-gem NAME')
      expect(out.string).to be_empty
    end

    it 'prints public provider-gem help' do
      out = StringIO.new
      err = StringIO.new

      status = described_class.run(%w[provider-gem --help], out: out, err: err)

      expect(status).to eq(0)
      expect(err.string).to be_empty
      expect(out.string).to include('Usage: ruby_llm provider-gem NAME [options]')
      expect(out.string).to include('--github-owner')
      expect(out.string).to include('--skip-bundle')
      expect(out.string).to include('Exact directory to write into')
      expect(out.string).not_to include('--models-dev-provider')
    end
  end

  describe 'bare invocation' do
    it 'prints help and succeeds' do
      out = StringIO.new

      expect(described_class.run([], out: out, err: StringIO.new)).to eq(0)
      expect(out.string).to include('ruby_llm provider-gem NAME')
    end

    it 'prints help for the help command' do
      out = StringIO.new

      expect(described_class.run(['help'], out: out, err: StringIO.new)).to eq(0)
      expect(out.string).to include('Usage:')
    end
  end

  describe 'repository executable' do
    it 'generates from outside the RubyLLM checkout' do
      executable = File.expand_path('../../exe/ruby_llm', __dir__)
      destination = File.join(dir, 'ruby_llm-providers-acme')
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        executable,
        'provider-gem',
        'Acme',
        '--api-base',
        'https://api.acme.ai/v1',
        '--skip-bundle',
        chdir: dir
      )

      expect(status.success?).to be(true), stderr
      expect(stderr).to be_empty
      expect(stdout).to include("create  #{destination}")
      expect(stdout).to include('create  ruby_llm-providers-acme.gemspec')
      expect(stdout).to include('run  git init')
      expect(File.exist?(File.join(destination, 'ruby_llm-providers-acme.gemspec'))).to be(true)
      expect(Dir.exist?(File.join(destination, '.git'))).to be(true)
    end
  end

  describe 'argument errors' do
    it 'reports a missing provider name' do
      err = StringIO.new

      expect(described_class.run(['provider-gem'], out: StringIO.new, err: err)).to eq(1)
      expect(err.string).to include('Usage: ruby_llm provider-gem NAME')
    end

    it 'reports extra arguments' do
      err = StringIO.new

      expect(described_class.run(%w[provider-gem acme extra], out: StringIO.new, err: err)).to eq(1)
      expect(err.string).to include('Unexpected arguments: extra')
    end

    it 'reports an unknown option' do
      err = StringIO.new

      expect(described_class.run(%w[provider-gem acme --nope], out: StringIO.new, err: err)).to eq(1)
      expect(err.string).to include('invalid option')
    end
  end

  describe '.parse_options' do
    it 'collects every gem option' do
      name, options = described_class.parse_options(
        %w[--destination /tmp/out --api-base https://api.acme.test
           --api-key-env ACME_API_KEY --api-base-env ACME_API_BASE --dialect chat_completions
           --dynamic-models --gem-name ruby_llm-acme --github-owner acme --skip-bundle --force acme],
        mode: 'gem'
      )

      expect(name).to eq('acme')
      expect(options).to include(
        mode: 'gem', destination: '/tmp/out', api_base: 'https://api.acme.test',
        api_key_env: 'ACME_API_KEY', api_base_env: 'ACME_API_BASE', dialect: 'chat_completions',
        dynamic_models: true, gem_name: 'ruby_llm-acme', github_owner: 'acme', skip_bundle: true, force: true
      )
    end

    it 'leaves the provider gem destination for the scaffold to derive from its name' do
      _name, options = described_class.parse_options(%w[acme], mode: 'gem')

      expect(options).not_to have_key(:destination)
    end

    it 'accepts the core-only models.dev option' do
      _name, options = described_class.parse_options(%w[--models-dev-provider acme acme], mode: 'core')

      expect(options[:models_dev_provider]).to eq('acme')
      expect(options).not_to have_key(:gem_name)
    end

    it 'names the core script in its usage banner' do
      expect { described_class.parse_options(['--help'], mode: 'core') }.to raise_error(
        described_class::HelpRequested, %r{script/generate-provider NAME}
      )
    end
  end

  describe 'skipped files' do
    it 'reports what it left alone on a second run' do
      arguments = %w[provider-gem acme --destination] + [dir, '--skip-bundle']
      described_class.run(arguments, out: StringIO.new, err: StringIO.new)
      out = StringIO.new

      status = described_class.run(arguments, out: out, err: StringIO.new)

      expect(status).to eq(0)
      expect(out.string).to include('skip  .gitignore')
    end
  end

  it 'installs the bundle after initializing Git' do
    cli = described_class.new(
      %w[provider-gem acme --destination] + [dir],
      out: StringIO.new,
      err: StringIO.new
    )
    allow(cli).to receive_messages(initialize_git_repository: true, install_dependencies: true)

    expect(cli.run).to eq(0)
    expect(cli).to have_received(:initialize_git_repository).with(dir).ordered
    expect(cli).to have_received(:install_dependencies).with(dir).ordered
  end
end
