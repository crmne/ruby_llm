# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ResearchJob do
  let(:protocol) { instance_double(RubyLLM::Protocols::VertexAI::Research) }
  let(:job) { described_class.new(id: 'job-1', provider: :vertexai, agent: 'agent-id', protocol:, status: :pending) }

  it 'retains a timed-out independent task without cancelling it' do
    allow(protocol).to receive(:refresh_research_job).with(job, timeout: be > 0).and_return(status: :pending)
    allow(protocol).to receive(:cancel_research_job)

    expect { job.wait(timeout: 0.01, interval: 0.01) }
      .to raise_error(described_class::TimeoutError) { |error| expect(error.job).to equal(job) }
    expect(job).to be_pending
    expect(protocol).not_to have_received(:cancel_research_job)
  end

  it 'attempts bounded cancellation when the blocking convenience times out before returning a handle' do
    allow(described_class).to receive(:research_later).and_return(job)
    allow(job).to receive(:wait).and_raise(described_class::TimeoutError.new('Timed out', job:))
    allow(protocol).to receive(:cancel_research_job).with(job, timeout: 5).and_return(status: :cancelled)

    expect { described_class.research('Question', provider: :vertexai, agent: 'agent-id') }
      .to raise_error(described_class::TimeoutError) { |error| expect(error.job).to equal(job) }
    expect(job).to be_cancelled
  end

  it 'retains the job and cancellation error when timeout cleanup cannot be confirmed' do
    allow(described_class).to receive(:research_later).and_return(job)
    original = described_class::TimeoutError.new('Timed out', job:)
    allow(job).to receive(:wait).and_raise(original)
    allow(protocol).to receive(:cancel_research_job).and_raise(Faraday::TimeoutError, 'Cancellation timed out')

    expect { described_class.research('Question', provider: :vertexai, agent: 'agent-id') }
      .to(raise_error { |error| expect(error).to equal(original) })
    expect(job).to be_pending
    expect(job.cancellation_error).to be_a(described_class::TimeoutError)
    expect(job.cancellation_error.cause).to be_a(Faraday::TimeoutError)
  end

  it 'preserves interruption semantics and the job handle after a blocking call is interrupted' do
    allow(described_class).to receive(:research_later).and_return(job)
    original = Interrupt.new('Stop waiting')
    allow(job).to receive(:wait).and_raise(original)
    allow(protocol).to receive(:cancel_research_job).with(job, timeout: 5).and_return(status: :cancelled)

    expect { described_class.research('Question', provider: :vertexai, agent: 'agent-id') }
      .to raise_error(described_class::InterruptedError) do |error|
        expect(error).to be_a(Interrupt)
        expect(error.cause).to equal(original)
        expect(error.job).to equal(job)
      end
  end

  it 'rejects invalid polling settings before submitting work or sending a cancellation' do
    allow(described_class).to receive(:research_later)
    expect { described_class.research('Question', timeout: 0, provider: :vertexai, agent: 'agent-id') }
      .to raise_error(ArgumentError, /positive finite/)
    expect { job.wait(timeout: Float::INFINITY) }.to raise_error(ArgumentError, /positive finite/)
    expect { job.cancel(timeout: -1) }.to raise_error(ArgumentError, /positive finite/)
    expect(described_class).not_to have_received(:research_later)
  end

  it 'keeps absent billing information unknown without inventing model identity' do
    expect(job.tokens.to_h).to eq({})
    expect(job.cost.total).to be_nil
    expect(job).to have_attributes(agent: 'agent-id', provider: :vertexai, id: 'job-1')
    expect(job.inspect).to include('job-1', 'pending')
  end
end
