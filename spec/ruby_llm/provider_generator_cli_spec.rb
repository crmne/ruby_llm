# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'

RSpec.describe RubyLLM::ProviderGeneratorCLI do
  let(:dir) { Dir.mktmpdir('ruby_llm_provider_cli') }

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
          '--model',
          'acme-chat'
        ],
        out: out,
        err: err
      )

      expect(status).to eq(0)
      expect(err.string).to be_empty
      expect(out.string).to include('Generated')
      expect(File.exist?(File.join(dir, 'lib/ruby_llm/acme_ai.rb'))).to be(true)
      expect(File.exist?(File.join(dir, 'ruby_llm-acme-ai.gemspec'))).to be(true)
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
        %w[--destination /tmp/out --api-base https://api.acme.test --model acme-1
           --api-key-env ACME_API_KEY --api-base-env ACME_API_BASE --dialect chat_completions
           --dynamic-models --gem-name ruby_llm-acme --github-owner acme --force acme],
        mode: 'gem'
      )

      expect(name).to eq('acme')
      expect(options).to include(
        mode: 'gem', destination: '/tmp/out', api_base: 'https://api.acme.test', model: 'acme-1',
        api_key_env: 'ACME_API_KEY', api_base_env: 'ACME_API_BASE', dialect: 'chat_completions',
        dynamic_models: true, gem_name: 'ruby_llm-acme', github_owner: 'acme', force: true
      )
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
      described_class.run(%w[provider-gem acme --destination] + [dir], out: StringIO.new, err: StringIO.new)
      out = StringIO.new

      status = described_class.run(%w[provider-gem acme --destination] + [dir], out: out, err: StringIO.new)

      expect(status).to eq(0)
      expect(out.string).to match(/Skipped \d+ existing files/)
    end
  end
end
