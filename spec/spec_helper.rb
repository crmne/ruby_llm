# frozen_string_literal: true

require 'dotenv/load'
require 'simplecov'
require 'simplecov-cobertura'
require 'codecov'
require 'vcr'
require 'bundler/setup'
require 'fileutils'
require 'ruby_llm'
require 'webmock/rspec'
require 'active_support'
require 'active_support/core_ext'
require_relative 'support/rspec_configuration'
require_relative 'support/rubyllm_configuration'
require_relative 'support/simplecov_configuration'
require_relative 'support/vcr_configuration'
require_relative 'support/models_to_test'
require_relative 'support/streaming_error_helpers'

def save_and_verify_image(image)
  # Create a temp file to save to
  temp_file = Tempfile.new(['image', '.png'])
  temp_path = temp_file.path
  temp_file.close

  begin
    saved_path = image.save(temp_path)
    expect(saved_path).to eq(temp_path)
    expect(File.exist?(temp_path)).to be true

    file_size = File.size(temp_path)
    expect(file_size).to be > 1000 # Any real image should be larger than 1KB
  ensure
    # Clean up
    File.delete(temp_path)
  end
end
