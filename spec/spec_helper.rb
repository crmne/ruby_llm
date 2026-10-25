# frozen_string_literal: true

require 'dotenv'
# .env holds 1Password lookups for recording; CI has neither, and replays.
Dotenv.load unless ENV['CI']
require_relative 'support/blank_keys'
require 'simplecov'
require 'simplecov-cobertura'
require_relative 'support/simplecov_configuration'
require 'vcr'
require 'bundler/setup'
require 'fileutils'
require 'tempfile'
require 'ruby_llm'
RubyLLM.config.model_registry_file = nil
require 'schematist'
require 'webmock/rspec'
require 'active_support'
require 'active_support/core_ext'
require_relative 'support/rspec_configuration'
require_relative 'support/rubyllm_configuration'
require_relative 'support/vcr_configuration'
require_relative 'support/models_to_test'
require_relative 'support/chat_helpers'
require_relative 'support/capture_instrumenter'
require_relative 'support/streaming_error_helpers'
require_relative 'support/request_shape_helpers'
require_relative 'support/socket_configuration'
require_relative 'support/keep_alive_server'
require_relative 'support/reactor_helpers'
require_relative 'support/git_environment'
require_relative 'support/fake_sandbox'
require_relative 'support/file_store_contract'
require_relative 'support/sandbox_backend'

RubyLLM.config.deprecation_behavior = ENV['RUBYLLM_STRICT_DEPRECATIONS'] == 'true' ? :raise : :silence
