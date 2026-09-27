# frozen_string_literal: true

require 'spec_helper'
require 'active_record'
require 'thor'
require 'generators/ruby_llm/generator_helpers'

RSpec.describe RubyLLM::Generators::GeneratorHelpers, :generator do
  describe 'database detection' do
    let(:helpers) { Object.new.extend(described_class) }

    def connect_to(*class_names)
      adapter = class_names.reverse.inject(Object) do |parent, class_name|
        Class.new(parent) { define_singleton_method(:name) { class_name } }
      end
      allow(ActiveRecord::Base).to receive(:connection).and_return(adapter.allocate)
    end

    it 'recognizes adapters built on PostgreSQL, such as PostGIS' do
      connect_to('ActiveRecord::ConnectionAdapters::PostGISAdapter',
                 'ActiveRecord::ConnectionAdapters::PostgreSQLAdapter')

      expect(helpers).to be_postgresql
      expect(helpers).not_to be_mysql
    end

    it 'recognizes adapters built on MySQL, such as Trilogy' do
      connect_to('ActiveRecord::ConnectionAdapters::TrilogyAdapter',
                 'ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter')

      expect(helpers).to be_mysql
      expect(helpers).not_to be_postgresql
    end

    it 'treats other adapters as neither' do
      connect_to('ActiveRecord::ConnectionAdapters::SQLite3Adapter')

      expect(helpers).not_to be_postgresql
      expect(helpers).not_to be_mysql
    end

    it 'treats an unavailable connection as neither' do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(ActiveRecord::ConnectionNotEstablished)

      expect(helpers).not_to be_postgresql
      expect(helpers).not_to be_mysql
    end
  end

  describe '.reorder_arguments' do
    let(:options) do
      {
        mode: Thor::Option.new('mode', type: :string),
        output_format: Thor::Option.new('output_format', type: :string, aliases: ['-o']),
        quiet: Thor::Option.new('quiet', type: :boolean, aliases: ['-q']),
        force: Thor::Option.new('force', type: :boolean, aliases: ['-f']),
        skip_active_storage: Thor::Option.new('skip_active_storage', type: :boolean)
      }
    end

    it 'keeps values for options whose names are dasherized by Thor' do
      args = ['--output-format', 'json', 'chat:Chat', 'message:Message']

      expect(described_class.reorder_arguments(args, options)).to eq(
        ['chat:Chat', 'message:Message', '--output-format', 'json']
      )
    end

    it 'keeps values for aliased options and does not consume boolean options' do
      args = ['-o', 'json', '--force', 'chat:Chat']

      expect(described_class.reorder_arguments(args, options)).to eq(
        ['chat:Chat', '-o', 'json', '--force']
      )
    end

    it 'keeps equals-form options after the mappings' do
      args = ['--mode=copy', 'chat:Chat']

      expect(described_class.reorder_arguments(args, options)).to eq(
        ['chat:Chat', '--mode=copy']
      )
    end

    %w[--force -f -qf --no-force --skip-force --skip-active-storage --skip_active_storage].each do |switch|
      %w[true TRUE t T false FALSE f F].each do |value|
        it "preserves #{switch} #{value} as an explicit boolean" do
          args = [switch, value, 'chat:Chat']
          reordered = described_class.reorder_arguments(args, options)

          expect(reordered).to eq(['chat:Chat', switch, value])
          expect(Thor::Options.new(options).parse(reordered)).to eq(Thor::Options.new(options).parse(args))
        end
      end
    end

    it 'keeps negated string options separate from mappings' do
      args = ['--no-mode', 'chat:Chat']

      expect(described_class.reorder_arguments(args, options)).to eq(['chat:Chat', '--no-mode'])
    end

    it 'preserves the end-of-options boundary' do
      args = ['--force', 'chat:Chat', '--', '--mode', 'copy', 'message:Message']
      reordered = described_class.reorder_arguments(args, options)
      parser = Thor::Options.new(options)

      expect(reordered).to eq(['chat:Chat', '--force', '--', '--mode', 'copy', 'message:Message'])
      expect(parser.parse(reordered)).to include('force' => true)
      expect(parser.remaining).to eq(['chat:Chat', '--mode', 'copy', 'message:Message'])
    end

    it 'leaves the token after an unknown switch positional' do
      args = ['--unknown', 'chat:Chat', 'message:Message']

      expect(described_class.reorder_arguments(args, options)).to eq(
        ['chat:Chat', 'message:Message', '--unknown']
      )
    end
  end
end
