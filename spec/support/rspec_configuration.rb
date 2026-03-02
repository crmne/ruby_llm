# frozen_string_literal: true

require 'fileutils'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

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
end
