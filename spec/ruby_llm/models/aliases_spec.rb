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

  it 'loads the aliases once when threads ask for them together' do
    loaded = described_class.aliases
    described_class.instance_variable_set(:@aliases, nil)
    loads = 0
    allow(described_class).to receive(:load_aliases) do
      loads += 1
      sleep 0.05
      loaded
    end

    results = Array.new(8) { Thread.new { described_class.aliases } }.map(&:value)

    expect(results.map(&:object_id).uniq.size).to eq(1)
    expect(loads).to eq(1)
  ensure
    described_class.instance_variable_set(:@aliases, loaded)
  end
end
