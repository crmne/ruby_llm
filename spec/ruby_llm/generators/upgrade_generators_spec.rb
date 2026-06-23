# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/upgrade/upgrade_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe 'RubyLLM upgrade generator', :generator, type: :generator do # rubocop:disable RSpec/DescribeClass
  include GeneratorTestHelpers

  def migrations_containing(pattern)
    Dir.glob('db/migrate/*.rb').select { |path| path.include?(pattern) }
  end

  describe 'with default model names' do
    let(:app_name) { 'test_upgrade_generator_default' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generator_default'))
      GeneratorTestHelpers.create_test_app(
        'test_upgrade_generator_default',
        template: 'upgrade_generators_default_template.rb',
        template_path: template_path
      )
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generator_default'))
    end

    it 'creates the v2.0 migration adding message columns and the batches table' do
      within_test_app(app_path) do
        migration_path = migrations_containing('add_ruby_llm_v2_0_columns').first
        expect(migration_path).not_to be_nil

        migration = File.read(migration_path)
        expect(migration).to include('add_column :messages, :citations, :json')
        expect(migration).to include('add_column :messages, :finish_reason, :string')
        expect(migration).to include('create_table :batches')
      end
    end
  end

  describe 'with custom model mappings' do
    let(:app_name) { 'test_upgrade_generator_custom_mappings' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generator_custom_mappings'))
      GeneratorTestHelpers.create_test_app(
        'test_upgrade_generator_custom_mappings',
        template: 'upgrade_generators_custom_mappings_template.rb',
        template_path: template_path
      )
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generator_custom_mappings'))
    end

    it 'creates a v2.0 migration targeting the mapped message table' do
      within_test_app(app_path) do
        migration_path = migrations_containing('add_ruby_llm_v2_0_columns').first
        expect(migration_path).not_to be_nil

        migration = File.read(migration_path)
        expect(migration).to include('add_column :chat_messages, :citations, :json')
        expect(migration).to include('add_column :chat_messages, :finish_reason, :string')
        expect(migration).to include('create_table :batches')
      end
    end
  end
end
