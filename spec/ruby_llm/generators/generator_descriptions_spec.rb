# frozen_string_literal: true

require 'rails_helper'
require 'generators/ruby_llm/install/install_generator'
require 'generators/ruby_llm/upgrade/upgrade_generator'
require 'generators/ruby_llm/chat_ui/chat_ui_generator'

RSpec.describe 'Generator descriptions' do # rubocop:disable RSpec/DescribeClass
  [
    RubyLLM::Generators::InstallGenerator,
    RubyLLM::Generators::UpgradeGenerator,
    RubyLLM::Generators::ChatUIGenerator
  ].each do |generator|
    it "puts the usage of #{generator.namespace} on its own line" do
      expect(generator.desc.lines.map(&:chomp)).to include(a_string_starting_with('Usage: bin/rails g'))
    end
  end
end
