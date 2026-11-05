# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

RSpec.describe 'Site facts', type: :task do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:config) { YAML.load_file(File.join(root, 'docs/_config.yml')) }

  it 'counts the providers RubyLLM registers' do
    registered = File.read(File.join(root, 'lib/ruby_llm.rb')).scan(/^RubyLLM::Provider\.register /).size

    expect(config['provider_count']).to eq(registered)
  end

  it 'gives the README the same provider count as the site' do
    readme = File.read(File.join(root, 'README.md'))

    expect(readme).to include("## #{config['provider_count']} providers. One API.")
  end

  it 'names the released gem version' do
    expect(config['gem_version']).to eq(RubyLLM::VERSION)
  end
end
