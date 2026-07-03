# frozen_string_literal: true

require 'fileutils'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  status_suffix = ENV['TEST_ENV_NUMBER'].to_s
  config.example_status_persistence_file_path = ".rspec_status#{status_suffix}"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around do |example|
    cassette_name = example.full_description.parameterize(separator: '_').delete_prefix('rubyllm_')
    cassette_path = File.join(VCR.configuration.cassette_library_dir, "#{cassette_name}.yml")

    VCR.use_cassette(cassette_name) do
      example.run
    end

    FileUtils.rm_f(cassette_path) if example.exception
  end

  # Replaying VertexAI cassettes must not hit Google auth; live recording still does.
  config.before do
    unless VCR.current_cassette&.recording?
      allow_any_instance_of(RubyLLM::Providers::VertexAI) # rubocop:disable RSpec/AnyInstance
        .to receive(:headers).and_return({ 'Authorization' => 'Bearer test-token' })
    end
  end
end
