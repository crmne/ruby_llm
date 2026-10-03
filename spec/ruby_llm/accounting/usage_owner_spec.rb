# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Accounting::Usage do
  include_context 'with configured RubyLLM'

  let(:instrumenter) { CaptureInstrumenter.new }
  let(:context) { RubyLLM.context { |config| config.instrumenter = instrumenter } }
  let(:model) { model_for(:openai, :embedding) }

  before do
    allow(described_class).to receive(:ledger).and_return(nil)
    stub_request(:post, 'https://api.openai.com/v1/embeddings').to_return(
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: { model:, data: [{ embedding: [0.1, 0.2] }], usage: { prompt_tokens: 3, total_tokens: 3 } }.to_json
    )
  end

  def embed(**)
    context.embed('Ruby', model:, provider: :openai, **)
  end

  def usage_owners
    usage_events = instrumenter.events.filter_map { |name, payload| payload if name == 'usage.ruby_llm' }
    usage_events.map { |payload| payload[:owner] }
  end

  it 'includes the keyword owner in the usage instrumentation payload' do
    embed(owner: 'account-1')

    event = instrumenter.events.find { |name, _| name == 'usage.ruby_llm' }
    expect(event.last).to include(operation: :embedding, status: :succeeded, owner: 'account-1')
  end

  it 'reports no owner outside a block and without the keyword' do
    embed

    expect(instrumenter.events.find { |name, _| name == 'usage.ruby_llm' }.last).to include(owner: nil)
  end

  it 'applies the ambient owner, lets the keyword win, and restores outer owners' do
    RubyLLM.with_usage_owner('outer') do
      embed
      embed(owner: 'keyword')
      RubyLLM.with_usage_owner('inner') { embed }
      embed
    end
    embed

    expect(usage_owners).to eq(['outer', 'keyword', 'inner', 'outer', nil])
  end

  it 'returns the block value and restores the owner when the block raises' do
    expect(RubyLLM.with_usage_owner('account-1') { :done }).to eq(:done)
    expect { RubyLLM.with_usage_owner('account-1') { raise 'boom' } }.to raise_error('boom')

    embed
    expect(usage_owners).to eq([nil])
  end

  it 'keeps each thread and fiber to its own owner' do
    ready = Queue.new
    proceed = Queue.new
    threads = %w[thread-1 thread-2].map do |owner|
      Thread.new do
        RubyLLM.with_usage_owner(owner) do
          ready << true
          proceed.pop
          embed
        end
      end
    end
    2.times { ready.pop }
    2.times { proceed << true }
    threads.each(&:join)

    fiber = Fiber.new do
      RubyLLM.with_usage_owner('fiber') do
        Fiber.yield
        embed
      end
    end
    fiber.resume
    embed
    fiber.resume

    expect(usage_owners).to contain_exactly('thread-1', 'thread-2', nil, 'fiber')
    expect(usage_owners.last(2)).to eq([nil, 'fiber'])
  end

  it 'passes the owner to threads started inside the block' do
    RubyLLM.with_usage_owner('parent') { Thread.new { embed }.join }

    expect(usage_owners).to eq(['parent'])
  end
end
