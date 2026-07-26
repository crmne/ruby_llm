# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'
require 'tmpdir'

RSpec.describe RubyLLM::ProviderScaffold do
  let(:dir) { Dir.mktmpdir('ruby_llm_provider_scaffold') }

  after do
    FileUtils.rm_rf(dir)
  end

  describe '#generate!' do
    it 'generates a standalone provider gem that boots' do
      result = described_class.new(
        'OllamaCloud',
        mode: :gem,
        destination: dir,
        api_base: 'https://ollama.com/v1',
        model: 'gpt-oss-120b',
        github_owner: 'crmne'
      ).generate!

      expect(result.written).to include(
        'Gemfile',
        'Appraisals',
        'Archspec.rb',
        '.flayignore',
        '.github/workflows/ci.yml',
        '.github/workflows/release.yml',
        'lib/ruby_llm/ollama_cloud.rb',
        'lib/ruby_llm/providers/ollama_cloud.rb',
        'spec/ruby_llm/chat_spec.rb',
        'spec/ruby_llm/chat_streaming_spec.rb',
        'spec/ruby_llm/models_spec.rb'
      )
      expect(File.executable?(File.join(dir, 'bin/setup'))).to be(true)

      provider = File.read(File.join(dir, 'lib/ruby_llm/providers/ollama_cloud.rb'))
      expect(provider).to include('class OllamaCloud < Provider')
      expect(provider).to include('protocol :chat_completions, ChatCompletions')
      expect(provider).to include('def assume_models_exist?')

      gemspec = File.read(File.join(dir, 'ruby_llm-ollama-cloud.gemspec'))
      expect(gemspec).to include("spec.add_dependency 'ruby_llm', '>= 2.0'")

      provider_spec = File.read(File.join(dir, 'spec/ruby_llm/providers/ollama_cloud_spec.rb'))
      expect(provider_spec).to include('include(chat_completions: described_class::ChatCompletions)')

      ci = File.read(File.join(dir, '.github/workflows/ci.yml'))
      expect(ci).to include('appraisal: ["ruby-llm-latest", "ruby-llm-main"]')
      expect(ci).to include('bundle exec appraisal generate')
      expect(ci).to include('bundle exec appraisal ${{ matrix.appraisal }} bundle install')

      assert_generated_gem_boots
    end

    it 'generates a first-party core provider and updates core wiring' do
      create_core_fixture

      result = described_class.new(
        'OllamaCloud',
        mode: :core,
        destination: dir,
        api_base: 'https://ollama.com/v1',
        model: 'gpt-oss-120b',
        api_key_env: 'OLLAMA_CLOUD_API_KEY',
        api_base_env: 'OLLAMA_CLOUD_API_BASE',
        dialect: :ollama,
        models_dev_provider: 'ollama-cloud',
        dynamic_models: true
      ).generate!

      expect(result.written).to include(
        'lib/ruby_llm/providers/ollama_cloud.rb',
        'lib/ruby_llm/providers/ollama_cloud/capabilities.rb',
        'spec/ruby_llm/providers/ollama_cloud_spec.rb',
        'spec/ruby_llm/providers/ollama_cloud/capabilities_spec.rb'
      )
      expect(result.updated).to include(
        'lib/ruby_llm.rb',
        '.env.example',
        'spec/support/rubyllm_configuration.rb',
        'spec/support/vcr_configuration.rb',
        'lib/ruby_llm/models.rb'
      )

      provider = File.read(File.join(dir, 'lib/ruby_llm/providers/ollama_cloud.rb'))
      expect(provider).to include('class ChatCompletions < Ollama::ChatCompletions')
      expect(provider).to include('def assume_models_exist?')

      provider_spec = File.read(File.join(dir, 'spec/ruby_llm/providers/ollama_cloud_spec.rb'))
      expect(provider_spec).to include('include(chat_completions: described_class::ChatCompletions)')

      entrypoint = File.read(File.join(dir, 'lib/ruby_llm.rb'))
      expect(entrypoint).to include("'ollama_cloud' => 'OllamaCloud',")
      expect(entrypoint).to include('RubyLLM::Provider.register :ollama_cloud, RubyLLM::Providers::OllamaCloud')

      models = File.read(File.join(dir, 'lib/ruby_llm/models.rb'))
      expect(models).to include("'ollama-cloud' => 'ollama_cloud',")
    end

    it 'rejects names that could escape the destination' do
      expect do
        described_class.new('../Acme', mode: :gem, destination: dir)
      end.to raise_error(ArgumentError, /provider name must start with a letter/)
    end
  end

  def create_core_fixture
    FileUtils.mkdir_p(File.join(dir, 'lib/ruby_llm'))
    FileUtils.mkdir_p(File.join(dir, 'spec/support'))

    FileUtils.cp(File.expand_path('../../lib/ruby_llm.rb', __dir__), File.join(dir, 'lib/ruby_llm.rb'))
    FileUtils.cp(File.expand_path('../../lib/ruby_llm/models.rb', __dir__), File.join(dir, 'lib/ruby_llm/models.rb'))
    FileUtils.cp(
      File.expand_path('../support/rubyllm_configuration.rb', __dir__),
      File.join(dir, 'spec/support/rubyllm_configuration.rb')
    )
    FileUtils.cp(
      File.expand_path('../support/vcr_configuration.rb', __dir__),
      File.join(dir, 'spec/support/vcr_configuration.rb')
    )
    File.write(File.join(dir, '.env.example'), "OPENAI_API_KEY=test\n")
  end

  def assert_generated_gem_boots
    script = <<~RUBY
      require 'ruby_llm/ollama_cloud'

      RubyLLM.configure do |config|
        config.ollama_cloud_api_key = 'test'
        config.ollama_cloud_api_base = 'https://ollama.com/v1'
      end

      model, provider = RubyLLM::Models.resolve('gpt-oss-120b', provider: :ollama_cloud)
      raise "bad model: \#{model.inspect}" unless model.id == 'gpt-oss-120b'
      raise "bad provider: \#{provider.inspect}" unless provider.is_a?(RubyLLM::Providers::OllamaCloud)
    RUBY

    env = {}
    env['BUNDLE_GEMFILE'] = ENV['BUNDLE_GEMFILE'] if ENV.key?('BUNDLE_GEMFILE')

    output, status = Open3.capture2e(
      env,
      RbConfig.ruby,
      '-Ilib',
      "-I#{File.join(dir, 'lib')}",
      '-e',
      script,
      chdir: File.expand_path('../..', __dir__)
    )
    expect(status.success?).to be(true), output
  end
end
