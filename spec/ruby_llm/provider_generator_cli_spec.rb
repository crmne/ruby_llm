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
end
