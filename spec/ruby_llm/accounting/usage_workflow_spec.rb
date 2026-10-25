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

  def usage_events
    instrumenter.events.filter_map { |name, payload| payload if name == 'usage.ruby_llm' }
  end

  it 'reports the workflow and step an attempt ran in' do
    context.workflow('Search', id: 'search-1') do |workflow|
      workflow.step('Embed', id: 'step-1') { context.embed('Ruby', model:, provider: :openai) }
    end
    context.embed('Ruby', model:, provider: :openai)

    expect(usage_events.first).to include(workflow_id: 'search-1', workflow_name: 'Search',
                                          workflow_step_id: 'step-1', workflow_step_name: 'Embed')
    expect(usage_events.last).not_to include(:workflow_id)
  end

  it 'reports the workflow a job was submitted in when it finishes in another one' do
    provider = instance_double(RubyLLM::Providers::Gemini, slug: 'gemini')
    protocol = instance_double(RubyLLM::Protocols::Gemini, config: context.config, provider:)
    research_protocol = instance_double(RubyLLM::Protocols::VertexAI::Research, config: context.config)
    allow(protocol).to receive(:refresh_video_job).and_return({ status: :completed })
    allow(research_protocol).to receive(:refresh_research_job).and_return(status: :completed)
    jobs = context.workflow('Launch', id: 'launch-1') do
      [RubyLLM::VideoJob.new(id: 'operations/op-1', protocol:, model: 'veo-3.1-fast-generate-preview'),
       RubyLLM::ResearchJob.new(id: 'job-1', provider: :vertexai, agent: 'agent-id', protocol: research_protocol,
                                status: :pending)]
    end

    context.workflow('Poll', id: 'poll-1') { jobs.each(&:refresh) }

    expect(usage_events.map { |event| event.values_at(:operation, :workflow_id, :workflow_name) })
      .to eq([[:video, 'launch-1', 'Launch'], [:research, 'launch-1', 'Launch']])
  end
end
