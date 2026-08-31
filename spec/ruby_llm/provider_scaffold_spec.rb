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

  describe '#generate' do
    it 'generates a standalone provider gem that boots' do
      result = described_class.new(
        'AcmeCloud',
        mode: :gem,
        destination: dir,
        api_base: 'https://api.acmecloud.example/v1',
        github_owner: 'crmne'
      ).generate

      expect(result.written).to include(
        'Gemfile',
        'Archspec.rb',
        '.flayignore',
        '.env',
        '.github/workflows/ci.yml',
        '.github/workflows/release.yml',
        'lib/ruby_llm/providers/acme_cloud.rb',
        'spec/ruby_llm/chat_spec.rb',
        'spec/ruby_llm/chat_streaming_spec.rb',
        'spec/ruby_llm/chat_tools_spec.rb',
        'spec/ruby_llm/chat_schema_spec.rb',
        'spec/ruby_llm/embedding_spec.rb',
        'spec/support/models.rb',
        'spec/ruby_llm/models_spec.rb'
      )
      expect(result.written).not_to include('Appraisals')
      expect(result.written).not_to include(
        'lib/ruby_llm/acme_cloud.rb',
        'lib/ruby_llm/acme_cloud/version.rb'
      )
      expect(File.executable?(File.join(dir, 'bin/setup'))).to be(true)

      provider = File.read(File.join(dir, 'lib/ruby_llm/providers/acme_cloud.rb'))
      expect(provider).to include("require 'ruby_llm'")
      expect(provider).to include('class AcmeCloud < Provider')
      expect(provider).to include('protocol :chat_completions, ChatCompletions')
      expect(provider).to include("def models_url\n          'models'")
      expect(provider).to include('def assume_models_exist?')
      expect(provider).to include('RubyLLM::Provider.register :acme_cloud, RubyLLM::Providers::AcmeCloud')
      expect(provider).to include("models: File.expand_path('../../../models.json', __dir__)")

      gemspec = File.read(File.join(dir, 'ruby_llm-providers-acme-cloud.gemspec'))
      expect(gemspec).to include("spec.version = '0.1.0'")
      expect(gemspec).to include("spec.add_dependency 'ruby_llm', '>= 2.0'")
      expect(gemspec).to include("Dir.glob('models.json')")
      expect(gemspec).not_to include('Appraisals')

      rakefile = File.read(File.join(dir, 'Rakefile'))
      expect(rakefile).to include('provider = RubyLLM::Provider.resolve!(:acme_cloud).new(RubyLLM.config)')
      expect(rakefile).to include("save_to_json(File.expand_path('models.json', __dir__))")

      provider_spec = File.read(File.join(dir, 'spec/ruby_llm/providers/acme_cloud_spec.rb'))
      expect(provider_spec).to include('include(chat_completions: described_class::ChatCompletions)')

      ci = File.read(File.join(dir, '.github/workflows/ci.yml'))
      expect(ci).not_to include('appraisal')

      appraisal_files = %w[Gemfile Rakefile bin/setup].map { |path| File.read(File.join(dir, path)) }.join
      expect(appraisal_files).not_to include('appraisal')
      expect(appraisal_files).not_to include('simplecov')

      env = File.read(File.join(dir, '.env'))
      expect(env).to include('ACME_CLOUD_API_KEY=$(op read "op://RubyLLM/AcmeCloud/credential")')
      expect(env).not_to include('RUN_PROVIDER_INTEGRATION')
      expect(File).not_to exist(File.join(dir, '.env.example'))

      models = File.read(File.join(dir, 'spec/support/models.rb'))
      expect(models).to include('CHAT_MODELS = [].freeze')
      expect(models).to include('TOOL_MODELS = CHAT_MODELS')
      expect(models).to include('EMBEDDING_MODELS = [].freeze')

      readme = File.read(File.join(dir, 'README.md'))
      expect(readme).to include('bundle exec rake models')
      expect(readme).to include('The suite always runs the provider integration specs.')

      vcr = File.read(File.join(dir, 'spec/support/vcr_configuration.rb'))
      expect(vcr).to include('config.allow_http_connections_when_no_cassette = true')
      expect(vcr).not_to include('RUN_PROVIDER_INTEGRATION')

      live_specs = Dir[File.join(dir, 'spec/ruby_llm/*_spec.rb')].map { |path| File.read(path) }.join
      expect(live_specs).not_to include('RUN_PROVIDER_INTEGRATION')

      spec_helper = File.read(File.join(dir, 'spec/spec_helper.rb'))
      expect(spec_helper).not_to include('SimpleCov')
      expect(File.read(File.join(dir, '.gitignore'))).not_to include('coverage')

      assert_generated_gem_boots
    end

    it 'generates a first-party core provider and updates core wiring' do
      create_core_fixture

      result = described_class.new(
        'AcmeCloud',
        mode: :core,
        destination: dir,
        api_base: 'https://api.acmecloud.example/v1',
        api_key_env: 'ACME_CLOUD_API_KEY',
        api_base_env: 'ACME_CLOUD_API_BASE',
        dialect: :ollama,
        models_dev_provider: 'acme-cloud',
        dynamic_models: true
      ).generate

      expect(result.written).to include(
        'lib/ruby_llm/providers/acme_cloud.rb',
        'spec/ruby_llm/providers/acme_cloud_spec.rb'
      )
      expect(result.written).not_to include(
        'lib/ruby_llm/providers/acme_cloud/capabilities.rb',
        'spec/ruby_llm/providers/acme_cloud/capabilities_spec.rb'
      )
      expect(result.updated).to include(
        'lib/ruby_llm.rb',
        '.env.example',
        'spec/support/rubyllm_configuration.rb',
        'spec/support/vcr_configuration.rb',
        'lib/ruby_llm/models.rb'
      )

      provider = File.read(File.join(dir, 'lib/ruby_llm/providers/acme_cloud.rb'))
      expect(provider).to include('class ChatCompletions < Ollama::ChatCompletions')
      expect(provider).to include('def assume_models_exist?')

      provider_spec = File.read(File.join(dir, 'spec/ruby_llm/providers/acme_cloud_spec.rb'))
      expect(provider_spec).to include('include(chat_completions: described_class::ChatCompletions)')

      entrypoint = File.read(File.join(dir, 'lib/ruby_llm.rb'))
      expect(entrypoint).to include("'acme_cloud' => 'AcmeCloud',")
      expect(entrypoint).to include('RubyLLM::Provider.register :acme_cloud, RubyLLM::Providers::AcmeCloud')

      models = File.read(File.join(dir, 'lib/ruby_llm/models.rb'))
      expect(models).to include("'acme-cloud' => 'acme_cloud',")
    end

    it 'resolves a shipped provider model without an explicit provider' do
      described_class.new('MiniMax', mode: :gem, destination: dir).generate
      models = [RubyLLM::Model.new(id: 'MiniMax-M3', name: 'MiniMax M3', provider: 'mini_max')]
      File.write(File.join(dir, 'models.json'), RubyLLM::ModelRegistry.pretty_json(models))

      script = <<~RUBY
        require 'ruby_llm/providers/mini_max'

        RubyLLM.configure { |config| config.mini_max_api_key = 'test' }
        model, provider = RubyLLM::Models.resolve('MiniMax-M3')

        raise "bad model: \#{model.inspect}" unless model.provider == 'mini_max'
        raise "bad provider: \#{provider.inspect}" unless provider.is_a?(RubyLLM::Providers::MiniMax)
      RUBY

      output, status = run_generated_ruby(script)

      expect(status.success?).to be(true), output
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
      require 'ruby_llm/providers/acme_cloud'

      RubyLLM.configure do |config|
        config.acme_cloud_api_key = 'test'
        config.acme_cloud_api_base = 'https://api.acmecloud.example/v1'
      end

      provider_class = RubyLLM::Provider.resolve!(:acme_cloud)
      provider = provider_class.new(RubyLLM.config)
      catalog = RubyLLM::Provider.model_registry_files.fetch(:acme_cloud)
      expected_catalog = File.expand_path('models.json', #{dir.inspect})

      raise "bad provider: \#{provider.inspect}" unless provider.is_a?(RubyLLM::Providers::AcmeCloud)
      raise 'dynamic models unexpectedly enabled' if provider_class.assume_models_exist?
      raise "bad catalog: \#{catalog.inspect}" unless catalog == expected_catalog
    RUBY

    output, status = run_generated_ruby(script)
    expect(status.success?).to be(true), output
  end

  def run_generated_ruby(script)
    env = {}
    env['BUNDLE_GEMFILE'] = ENV['BUNDLE_GEMFILE'] if ENV.key?('BUNDLE_GEMFILE')

    Open3.capture2e(
      env,
      RbConfig.ruby,
      '-Ilib',
      "-I#{File.join(dir, 'lib')}",
      '-e',
      script,
      chdir: File.expand_path('../..', __dir__)
    )
  end

  describe 'option handling' do
    it 'rejects a mode it does not support' do
      expect { described_class.new('Acme', mode: :plugin, destination: dir) }.to raise_error(
        ArgumentError, /unsupported mode: :plugin\. Expected one of: core, gem/
      )
    end

    it 'rejects a dialect it does not support' do
      expect { described_class.new('Acme', mode: :gem, dialect: :grpc, destination: dir) }.to raise_error(
        ArgumentError, /unsupported dialect: :grpc/
      )
    end

    it 'rejects gem names that could escape the generated directory' do
      expect do
        described_class.new('Acme', mode: :gem, gem_name: '../ruby_llm-providers-acme')
      end.to raise_error(ArgumentError, /gem name must contain only/)
    end

    it 'keeps a name that is already a class name' do
      expect(described_class.new('OpenAI', mode: :gem, destination: dir).class_name).to eq('OpenAI')
    end

    it 'fills in the defaults the CLI does not pass' do
      scaffold = described_class.new('Acme', mode: :gem, destination: dir)

      expect(scaffold.api_base).to eq('https://api.example.com/v1')
      expect(scaffold.api_key_env).to eq('ACME_API_KEY')
      expect(scaffold.api_base_env).to eq('ACME_API_BASE')
      expect(scaffold.gem_name).to eq('ruby_llm-providers-acme')
      expect(scaffold.github_owner).to eq('your-github-org')
      expect(scaffold.models_dev_provider).to be_nil
    end

    it 'creates provider gems in a named directory by default' do
      Dir.chdir(dir) do
        scaffold = described_class.new('AcmeCloud', mode: :gem)
        custom = described_class.new('AcmeCloud', mode: :gem, gem_name: 'ruby_llm-providers-custom')

        expect(scaffold.destination).to eq(File.join(dir, 'ruby_llm-providers-acme-cloud'))
        expect(custom.destination).to eq(File.join(dir, 'ruby_llm-providers-custom'))
      end
    end

    it 'treats a blank models.dev provider as none' do
      expect(described_class.new('Acme', mode: :core, models_dev_provider: '  ', destination: dir)
        .models_dev_provider).to be_nil
    end

    it 'reads every spelling of a truthy dynamic-models flag' do
      %w[true 1 yes on].each do |value|
        expect(described_class.new('Acme', mode: :gem, dynamic_models: value, destination: dir)).to be_dynamic_models
      end

      expect(described_class.new('Acme', mode: :gem, dynamic_models: 'no', destination: dir)).not_to be_dynamic_models
    end
  end

  describe 'core wiring when the core files are missing' do
    it 'writes the provider without touching files that are not there' do
      result = described_class.new(
        'Acme', mode: :core, destination: dir, models_dev_provider: 'acme'
      ).generate

      expect(result.written).to include('lib/ruby_llm/providers/acme.rb')
      expect(result.updated).to be_empty
    end
  end

  describe 'existing files' do
    it 'skips them unless asked to overwrite' do
      described_class.new('Acme', mode: :gem, destination: dir).generate

      result = described_class.new('Acme', mode: :gem, destination: dir).generate

      expect(result.written).to be_empty
      expect(result.skipped).not_to be_empty
    end

    it 'overwrites them with force' do
      described_class.new('Acme', mode: :gem, destination: dir).generate

      result = described_class.new('Acme', mode: :gem, destination: dir, force: true).generate

      expect(result.skipped).to be_empty
      expect(result.written).to be_empty
      expect(result.updated).not_to be_empty
      expect(result.actions).to all(satisfy { |action, _path| action == :updated })
    end
  end
end
