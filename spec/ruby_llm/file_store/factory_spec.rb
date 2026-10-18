# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::FileStore::Factory do
  include_context 'with configured RubyLLM'

  it 'is what RubyLLM.file_store returns' do
    expect(RubyLLM.file_store).to be(described_class)
  end

  it 'builds a new store in memory each time' do
    store = RubyLLM.file_store.memory

    expect(store).to be_a(RubyLLM::FileStore::Memory)
    expect(RubyLLM.file_store.memory).not_to be(store)
  end

  it 'builds a store in a folder, creating it' do
    root = Dir.mktmpdir('ruby_llm-file-store-factory')
    store = RubyLLM.file_store.directory(File.join(root, 'work'))

    expect(store).to be_a(RubyLLM::FileStore::Directory)
    expect(store.root).to eq(File.realpath(File.join(root, 'work')))
  ensure
    FileUtils.rm_rf(root)
  end

  it 'gives a chat the store it builds' do
    store = RubyLLM.file_store.memory
    chat = RubyLLM::Chat.new(model: model_for(:openai), provider: :openai)

    expect(chat.with_file_store(store).file_store).to be(store)
  end
end
