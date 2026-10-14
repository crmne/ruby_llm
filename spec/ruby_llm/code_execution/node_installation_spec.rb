# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::CodeExecution::NodeInstallation do
  it "finds the node executable behind the PATH's node, and the installation around it" do
    skip 'node is not on the PATH' unless system('node', '-e', '0', out: File::NULL, err: File::NULL)

    node = described_class.new
    executable = File.realpath(`node -p process.execPath`.strip)

    expect(node.bin_dir).to eq(File.dirname(executable))
    expect(node.readable).to eq([File.dirname(executable, 2)])
    expect(node.version).to eq(`node -p process.version`.strip)
  end

  it 'has nothing to mount without node' do
    node = described_class.new(node: 'ruby_llm-missing-node')

    expect([node.prefix, node.bin_dir, node.version, node.readable]).to eq([nil, nil, nil, []])
  end
end
