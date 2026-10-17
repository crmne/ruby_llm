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
    agent = agent_with { files }
    first = agent.new
    second = agent.new

    expect(first.files).to be_a(RubyLLM::FileStore::Memory)
    expect(first.files).not_to be(second.files)
    expect(first.tools.keys).to include(:read_file, :write_file)
  end

  it "passes options, and builds the store with a lambda in the agent's scope" do
    root = Dir.mktmpdir('ruby_llm-agent-files')
    agent = agent_with do
      inputs :folder
      files spill_over: 20, store: -> { RubyLLM::FileStore::Directory.new(File.join(folder, 'chat')) }
    end

    chat = agent.new(folder: root)

    expect(chat.files.root).to eq(File.realpath(File.join(root, 'chat')))
    expect(chat.chat.instance_variable_get(:@file_references).spill_over).to eq(20)
  ensure
    FileUtils.rm_rf(root)
  end

  it 'turns files off for a subclass, and rejects nil' do
    parent = agent_with { files }
    child = Class.new(parent) { files false }

    expect(child.new.files).to be_nil
    expect { agent_with { files nil } }.to raise_error(ArgumentError, /accepts true, false, or file options/)
  end

  it 'refuses a store that is not one, and a spill-over limit that is not one' do
    expect { agent_with { files store: 'tmp' } }.to raise_error(ArgumentError, /takes a RubyLLM::FileStore/)
    expect { RubyLLM::Tool.spill_over(0) }.to raise_error(ArgumentError, /positive number/)
  end

  it 'has no files unless asked' do
    expect(agent_with { nil }.new.files).to be_nil
  end
end
