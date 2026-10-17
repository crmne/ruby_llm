# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  def agent_with(&)
    Class.new(described_class) do
      model model_for(:openai), provider: :openai
      class_exec(&)
    end
  end

  it 'gives each chat a store of its own' do
    agent = agent_with { file_store }
    first = agent.new
    second = agent.new

    expect(first.file_store).to be_a(RubyLLM::FileStore::Memory)
    expect(first.file_store).not_to be(second.file_store)
    expect(first.tools.keys).to include(:read_file, :write_file)
  end

  it "passes options, and builds the store with a lambda in the agent's scope" do
    root = Dir.mktmpdir('ruby_llm-agent-files')
    agent = agent_with do
      inputs :folder
      file_store -> { RubyLLM::FileStore::Directory.new(File.join(folder, 'chat')) }, spill_to_file: 20
    end

    chat = agent.new(folder: root)

    expect(chat.file_store.root).to eq(File.realpath(File.join(root, 'chat')))
    expect(chat.chat.instance_variable_get(:@file_references).spill_to_file).to eq(20)
  ensure
    FileUtils.rm_rf(root)
  end

  it 'removes the store for a subclass with nil' do
    parent = agent_with { file_store }
    child = Class.new(parent) { file_store nil }

    expect(child.new.file_store).to be_nil
  end

  it 'refuses a store that is not one, and a spill_to_file limit that is not one' do
    expect { agent_with { file_store 'tmp' } }.to raise_error(ArgumentError, /takes a RubyLLM::FileStore/)
    expect { RubyLLM::Tool.spill_to_file(0) }.to raise_error(ArgumentError, /positive number/)
  end

  it 'has no store unless asked' do
    expect(agent_with { nil }.new.file_store).to be_nil
  end
end
