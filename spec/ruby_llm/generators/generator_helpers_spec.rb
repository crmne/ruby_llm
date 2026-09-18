# frozen_string_literal: true

require 'spec_helper'
require 'thor'
require 'generators/ruby_llm/generator_helpers'

RSpec.describe RubyLLM::Generators::GeneratorHelpers, :generator do
  describe '.reorder_arguments' do
    let(:options) do
      {
        output_format: Thor::Option.new('output_format', type: :string, aliases: ['-o']),
        force: Thor::Option.new('force', type: :boolean)
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
  end
end
