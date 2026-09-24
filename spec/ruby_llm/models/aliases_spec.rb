# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Models::Aliases do
  it 'reads UTF-8 aliases under an ASCII locale' do
    original_encoding = Encoding.default_external
    Encoding.default_external = Encoding::US_ASCII
    aliases = { 'français' => { 'openai' => 'gpt-5-nano' } }

    Dir.mktmpdir do |directory|
      path = File.join(directory, 'aliases.json')
      File.binwrite(path, JSON.generate(aliases))
      allow(described_class).to receive(:aliases_file).and_return(path)

      expect(described_class.load_aliases).to eq(aliases)
    end
  ensure
    Encoding.default_external = original_encoding
  end
end
