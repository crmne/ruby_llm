# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transport::ConnectionCache do
  subject(:cache) { described_class.new(limit: 2) }

  def fetch(key)
    cache.fetch(key) do
      builds << key
      Object.new
    end
  end

  let(:builds) { [] }

  it 'builds one connection per key and hands it out again' do
    first = fetch(:openai)

    expect(fetch(:openai)).to be(first)
    expect(fetch(:anthropic)).not_to be(first)
    expect(builds).to eq(%i[openai anthropic])
  end

  it 'forgets the least recently used connection beyond its limit' do
    fetch(:openai)
    fetch(:anthropic)
    fetch(:openai)
    fetch(:gemini)

    fetch(:openai)
    fetch(:anthropic)

    expect(builds).to eq(%i[openai anthropic gemini anthropic])
  end

  it 'forgets every connection when cleared' do
    first = fetch(:openai)
    cache.clear

    expect(fetch(:openai)).not_to be(first)
  end

  it 'builds a connection once when threads ask for it together' do
    connections = Array.new(8) do
      Thread.new do
        cache.fetch(:openai) do
          sleep 0.05
          builds << :openai
          Object.new
        end
      end
    end.map(&:value)

    expect(connections.uniq.size).to eq(1)
    expect(builds).to eq([:openai])
  end

  it 'builds new connections in a forked child instead of reusing the parent sockets' do
    parent = fetch(:openai)
    allow(Process).to receive(:pid).and_return(Process.pid + 1)

    child = fetch(:openai)

    expect(child).not_to be(parent)
    expect(fetch(:openai)).to be(child)
  end
end
