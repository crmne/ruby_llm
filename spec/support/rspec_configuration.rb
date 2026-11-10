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

    # Deliberate: a failing example must not keep its cassette. The missing file
    # makes the failure visible at a glance, and the next run re-records against
    # the live API instead of replaying a recording that may be hiding the bug.
    FileUtils.rm_f(cassette_path) if example.exception
  end

  # Examples set RubyLLM.config directly, so each one gets back the values it
  # started with: a retry count left behind otherwise reaches every later
  # example in the same worker. Hashes and arrays are copied, since options
  # such as file_converters are changed in place.
  config.around do |example|
    global = RubyLLM.config
    saved = RubyLLM::Configuration.options.to_h do |key|
      value = global.instance_variable_get(:"@#{key}")
      [key, value.is_a?(Hash) || value.is_a?(Array) ? value.dup : value]
    end
    example.run
  ensure
    saved.each { |key, value| global.instance_variable_set(:"@#{key}", value) }
  end

  # Connections, credentials, and confirmed provider files outlive a call,
  # so each example starts without the previous example's middleware,
  # adapters, tokens, and files.
  config.before do
    RubyLLM::Transport::Connection.cache.clear
    RubyLLM::Providers::VertexAI::Credentials.cache.clear
    RubyLLM::Protocols::VertexAI::Files::STORAGE_CLIENTS.clear
    RubyLLM::Protocol::StoredUploads.files.clear
  end

  # Replaying VertexAI cassettes must not hit Google auth; live recording still does.
  config.before do
    unless VCR.current_cassette&.recording?
      allow_any_instance_of(RubyLLM::Providers::VertexAI) # rubocop:disable RSpec/AnyInstance
        .to receive(:headers).and_return({ 'Authorization' => 'Bearer test-token' })
    end
  end
end
