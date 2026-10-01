# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Support::ProcessCache do
  subject(:cache) { described_class.new(limit: 2) }

  def fetch(key)
    cache.fetch(key) do
      builds << key
      Object.new
    end
  end

  let(:builds) { [] }

  it 'builds one value per key and hands it out again' do
    first = fetch(:openai)

    expect(fetch(:openai)).to be(first)
    expect(fetch(:anthropic)).not_to be(first)
    expect(builds).to eq(%i[openai anthropic])
  end

  it 'forgets the least recently used value beyond its limit' do
    fetch(:openai)
    fetch(:anthropic)
    fetch(:openai)
    fetch(:gemini)

    fetch(:openai)
    fetch(:anthropic)

    expect(builds).to eq(%i[openai anthropic gemini anthropic])
  end

  it 'forgets every value when cleared' do
    first = fetch(:openai)
    cache.clear

    expect(fetch(:openai)).not_to be(first)
  end

  it 'forgets one value when deleted' do
    openai = fetch(:openai)
    anthropic = fetch(:anthropic)
    cache.delete(:openai)

    expect(fetch(:openai)).not_to be(openai)
    expect(fetch(:anthropic)).to be(anthropic)
  end

  it 'hands every caller that races to build a value the first one stored' do
    values = Array.new(8) do
      Thread.new do
        cache.fetch(:openai) do
          sleep 0.05
          Object.new
        end
      end
    end.map(&:value)

    expect(values.uniq.size).to eq(1)
    expect(fetch(:openai)).to be(values.first)
  end

  it 'lets other threads through while a value is being built' do
    order = Queue.new
    building = Queue.new
    slow = Thread.new do
      cache.fetch(:slow) do
        building << true
        sleep 0.2
        order << :slow_built
        Object.new
      end
    end
    building.pop
    fetch(:fast)
    order << :fast_returned
    slow.join

    expect(Array.new(order.size) { order.pop }).to eq(%i[fast_returned slow_built])
  end

  it 'lets other fibers through while a value is being built' do
    order = []

    in_reactor do |task|
      slow = task.async do
        cache.fetch(:slow) do
          sleep 0.05
          order << :slow_built
          Object.new
        end
      end
      task.async { fetch(:fast) }.wait
      order << :fast_returned
      slow.wait
    end

    expect(order).to eq(%i[fast_returned slow_built])
  end

  it 'builds new values in a forked child instead of reusing the parent ones' do
    parent = fetch(:openai)
    allow(Process).to receive(:pid).and_return(Process.pid + 1)

    child = fetch(:openai)

    expect(child).not_to be(parent)
    expect(fetch(:openai)).to be(child)
  end
end
