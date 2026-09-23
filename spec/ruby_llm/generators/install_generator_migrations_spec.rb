# frozen_string_literal: true

require 'rails_helper'
require 'generators/ruby_llm/install/install_generator'

RSpec.describe RubyLLM::Generators::InstallGenerator, :generator do
  let(:destination) { Dir.mktmpdir('ruby_llm_install') }

  after { FileUtils.remove_entry(destination) }

  [nil, 'LLM'].each do |acronym|
    it "defines loadable migration classes #{acronym ? 'with an LLM acronym' : 'with default inflections'}" do
      inflections = ActiveSupport::Inflector.inflections.dup
      inflections.acronym(acronym) if acronym
      allow(ActiveSupport::Inflector).to receive(:inflections).and_return(inflections)

      generator = described_class.new([], {}, destination_root: destination, shell: Thor::Shell::Basic.new)
      generator.create_migration_files

      Dir.glob(File.join(destination, 'db/migrate/*.rb')).each do |path|
        namespace = Module.new
        namespace.module_eval(File.read(path), path)
        class_name = File.basename(path, '.rb').sub(/\A\d+_/, '').camelize

        expect(namespace.const_get(class_name, false)).to be < ActiveRecord::Migration
      end
    end
  end

  [nil, :uuid, :integer].each do |primary_key_type|
    context "with #{primary_key_type || 'default'} primary keys" do
      before do
        allow(Rails.application.config.generators).to receive(:options)
          .and_return(active_record: { primary_key_type: primary_key_type })
      end

      [[], %w[chat:Llm::Chat message:Llm::Message]].each do |mappings|
        it "uses matching primary and foreign key types with #{mappings.empty? ? 'default' : 'namespaced'} models" do
          generator = described_class.new(mappings, {}, destination_root: destination, shell: Thor::Shell::Basic.new)
          generator.create_migration_files
          migrations = Dir.glob(File.join(destination, 'db/migrate/*.rb')).map { |path| File.read(path) }.join("\n")
          key_type = primary_key_type || :bigint
          prefix = mappings.empty? ? '' : 'llm_'

          %W[#{prefix}chats #{prefix}messages ruby_llm_models ruby_llm_tool_calls ruby_llm_mcp_credentials
             ruby_llm_usages ruby_llm_batches]
            .each do |table|
              expect(migrations).to include("create_table :#{table}, id: :#{key_type} do |t|")
            end
          references = migrations.lines.grep(/t.references/)
          expect(references.size).to eq(7)
          expect(references).to all(include("type: :#{key_type}"))
        end
      end
    end
  end
end
