# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::VertexAI::Research do
  let(:agent) { 'deep-research-preview-04-2026' }
  let(:context) do
    RubyLLM.context do |config|
      config.vertexai_project_id = 'research-project'
      config.vertexai_location = 'global'
      config.max_retries = 2
      config.retry_interval = 0.5
      config.retry_max_interval = 0.5
    end
  end
  let(:provider) { RubyLLM::Providers::VertexAI.new(context.config) }
  let(:endpoint) { 'https://aiplatform.googleapis.com/v1beta1/projects/research-project/locations/global/interactions' }
  let(:completed) do
    pending.merge(status: 'completed', usage: { total_input_tokens: 100, total_cached_tokens: 10,
                                                total_output_tokens: 20, total_thought_tokens: 5 },
                  steps: [{ type: 'thought', summary: [{ text: 'Checked the documentation.' }] },
                          { type: 'mcp_server_tool_call', id: 'call-1', name: 'lookup', arguments: { query: 'Ruby' } },
                          { type: 'mcp_server_tool_result', call_id: 'call-1', name: 'lookup',
                            result: 'Documentation' },
                          { type: 'model_output', content: [
                            { type: 'text', text: 'Ruby documentation.', annotations: [
                              { type: 'url_citation', start_index: 0, end_index: 4, url: 'https://ruby-lang.org' }
                            ] }
                          ] }])
  end

  def pending
    { id: 'research-job', agent:, status: 'in_progress', object: 'interaction' }
  end

  before do |example|
    next if example.metadata[:live]

    allow(provider).to receive(:headers).and_return('Authorization' => 'Bearer research-test')
    allow(RubyLLM::Providers::VertexAI).to receive(:new).with(context.config).and_return(provider)
  end

  it 'submits once with explicit agent identity and MCP, then polls a typed report and exact usage' do
    submission = stub_request(:post, endpoint).with do |request|
      expect(JSON.parse(request.body)).to eq(
        'agent' => agent, 'background' => true, 'stream' => false,
        'input' => [{ 'type' => 'text', 'text' => 'Find Ruby documentation.' }],
        'tools' => [{ 'type' => 'mcp_server', 'name' => 'docs', 'url' => 'https://example.com/mcp' }]
      )
    end.to_return_json(body: pending)
    poll = stub_request(:get, "#{endpoint}/research-job").to_return_json(body: completed)

    job = context.research_later(
      'Find Ruby documentation.', provider: :vertexai, agent:,
                                  server_tools: { mcp: { name: 'docs', url: 'https://example.com/mcp' } }
    )
    expect(job).to be_pending
    expect(job.message).to be_nil
    expect(job.tokens.to_h).to eq({})
    job.wait(interval: 0.01)

    expect(job).to be_completed
    expect(job.message).to have_attributes(content: 'Ruby documentation.', model: nil, finish_reason: :stop)
    expect(job.message.citations.first).to have_attributes(url: 'https://ruby-lang.org', text: 'Ruby')
    expect(job.message.thinking.text).to eq('Checked the documentation.')
    expect(job.message.server_tool_calls.last).to have_attributes(id: 'call-1', name: 'lookup', result: 'Documentation')
    expect(job.tokens.to_h).to eq(input_tokens: 90, output_tokens: 25, cache_read_tokens: 10, thinking_tokens: 5)
    expect(job.cost.total).to be_nil
    expect(job.message.cost.total).to be_nil
    job.refresh
    expect(submission).to have_been_requested.once
    expect(poll).to have_been_requested.once
  end

  it 'retrieves an existing job and cancels it without submitting a second task' do
    stub_request(:get, "#{endpoint}/research-job").to_return_json(body: pending)
    cancellation = stub_request(:post, "#{endpoint}/research-job/cancel")
                   .with(body: '{}').to_return_json(body: pending.merge(status: 'cancelled'))

    job = RubyLLM::ResearchJob.find('research-job', provider: :vertexai, context:)
    job.cancel
    job.cancel

    expect(job).to be_cancelled
    expect { job.message }.to raise_error(RubyLLM::ResearchJob::Error) { |error| expect(error.job).to equal(job) }
    expect(cancellation).to have_been_requested.once
    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it 'keeps an unpriced hosted report unknown even when its actual token counts are zero' do
    stub_request(:get, "#{endpoint}/research-job").to_return_json(
      body: completed.merge(usage: { total_input_tokens: 0, total_output_tokens: 0 })
    )

    job = RubyLLM::ResearchJob.find('research-job', provider: :vertexai, context:)

    expect(job.tokens.to_h).to eq(input_tokens: 0, output_tokens: 0)
    expect(job.cost.total).to be_nil
    expect(job.message.cost.total).to be_nil
    expect(RubyLLM::Message.new(job.message.to_h).cost.total).to be_nil
  end

  it 'retains incomplete output with canonical finish reason and rejects missing successful reports' do
    stub_request(:get, "#{endpoint}/research-job").to_return_json(body: completed.merge(status: 'budget_exceeded'))
    job = RubyLLM::ResearchJob.find('research-job', provider: :vertexai, context:)
    expect(job).to be_incomplete
    expect(job.message.finish_reason).to eq(:max_tokens)

    stub_request(:get, "#{endpoint}/research-job").to_return_json(body: completed.merge(steps: []))
    expect { RubyLLM::ResearchJob.find('research-job', provider: :vertexai, context:) }
      .to raise_error(RubyLLM::Error, /without a report/)
  end

  it 'preserves provider failures and refuses unsupported action states' do
    stub_request(:get, "#{endpoint}/research-job")
      .to_return_json(body: pending.merge(status: 'failed', errors: [{ message: 'Research failed' }]))
    job = RubyLLM::ResearchJob.find('research-job', provider: :vertexai, context:)
    expect(job.error).to eq('Research failed')
    expect { job.wait }.to raise_error(RubyLLM::ResearchJob::Error, /Research failed/)

    stub_request(:get, "#{endpoint}/research-job").to_return_json(body: pending.merge(status: 'requires_action'))
    expect { RubyLLM::ResearchJob.find('research-job', provider: :vertexai, context:) }
      .to raise_error(RubyLLM::Error, /no recognized job state/)
  end

  it 'does not replay a failed non-idempotent submission' do
    context.config.max_retries = 2
    request = stub_request(:post, endpoint).to_return_json(status: 503, body: { error: { message: 'Try again' } })
    expect { context.research_later('Question', provider: :vertexai, agent:) }
      .to raise_error(RubyLLM::ServiceUnavailableError)
    expect(request).to have_been_requested.once
  end

  it 'bounds the entire polling request including retry backoff and preserves the job on timeout' do
    context.config.max_retries = 2
    context.config.retry_interval = 0.5
    stub_request(:post, endpoint).to_return_json(body: pending)
    poll = stub_request(:get, "#{endpoint}/research-job")
           .to_return_json(status: 503, body: { error: { message: 'Temporary polling failure' } })
    cancellation = stub_request(:post, "#{endpoint}/research-job/cancel")
                   .to_return_json(body: pending.merge(status: 'cancelled'))

    expect { context.research('Question', provider: :vertexai, agent:, timeout: 0.02, interval: 0.01) }
      .to raise_error(RubyLLM::ResearchJob::TimeoutError) { |error| expect(error.job).to be_cancelled }
    expect(poll).to have_been_requested.once
    expect(cancellation).to have_been_requested.once
  end

  it 'preserves polling errors and the remote handle while attempting bounded blocking cleanup' do
    context.config.max_retries = 0
    stub_request(:post, endpoint).to_return_json(body: pending)
    stub_request(:get, "#{endpoint}/research-job")
      .to_return_json(status: 503, body: { error: { message: 'Polling unavailable' } })
    cancellation = stub_request(:post, "#{endpoint}/research-job/cancel")
                   .to_return_json(body: pending.merge(status: 'cancelled'))

    expect { context.research('Question', provider: :vertexai, agent:) }
      .to raise_error(RubyLLM::ResearchJob::Error) do |error|
        expect(error.job.id).to eq('research-job')
        expect(error.cause).to be_a(RubyLLM::ServiceUnavailableError)
        expect(error.response.status).to eq(503)
      end
    expect(cancellation).to have_been_requested.once
  end

  it 'rejects unrelated agent families, transcript continuation and lifecycle overrides before submission' do
    expect { context.research_later('Question', provider: :vertexai, agent: 'unknown-agent') }
      .to raise_error(ArgumentError, /Deep Research agent/)
    %i[model previous_interaction_id background stream input agent].each do |key|
      expect do
        context.research_later('Question', provider: :vertexai, agent:, provider_options: { key => 'override' })
      end
        .to raise_error(ArgumentError, /only support/)
    end
    expect do
      context.research_later(
        'Question', provider: :vertexai, agent:,
                    server_tools: { mcp: { url: 'https://example.com/mcp', require_approval: 'always' } }
      )
    end.to raise_error(ArgumentError, /does not support: require_approval/)
    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it 'retains a successful submission ID when parsing fails and cancels it from the blocking facade' do
    stub_request(:post, endpoint).to_return_json(body: pending.merge(status: 'unrecognized'))
    cancellation = stub_request(:post, "#{endpoint}/research-job/cancel")
                   .to_return_json(body: pending.merge(status: 'cancelled'))

    expect { context.research('Question', provider: :vertexai, agent:) }
      .to raise_error(RubyLLM::ResearchJob::Error) do |error|
        expect(error.job).to have_attributes(id: 'research-job', status: :cancelled)
        expect(error.cause.response.body['status']).to eq('unrecognized')
      end
    expect(cancellation).to have_been_requested.once
  end

  it 'retains an existing job and the raw malformed poll response for recovery' do
    stub_request(:post, endpoint).to_return_json(body: pending)
    stub_request(:get, "#{endpoint}/research-job").to_return_json(body: [])
    job = context.research_later('Question', provider: :vertexai, agent:)

    expect { job.refresh }
      .to raise_error(RubyLLM::ResearchJob::Error) do |error|
        expect(error.job).to equal(job)
        expect(error.job.raw).to eq([])
        expect(error.job).to be_pending
      end
  end

  it 'renders document attachments and rejects audio before uploading or submitting anything' do
    pdf = RubyLLM::Attachment.new(StringIO.new('%PDF data'), filename: 'notes.pdf')
    request = stub_request(:post, endpoint).with do |req|
      expect(JSON.parse(req.body)['input'].last).to eq('type' => 'document', 'mime_type' => 'application/pdf',
                                                       'data' => pdf.encoded)
    end.to_return_json(body: pending)
    context.research_later('Question', provider: :vertexai, agent:, with: pdf)
    audio = RubyLLM::Attachment.new(StringIO.new('audio'), filename: 'speech.wav')
    expect { context.research_later('Question', provider: :vertexai, agent:, with: audio) }
      .to raise_error(RubyLLM::UnsupportedAttachmentError)
    expect(request).to have_been_requested.once
  end

  it 'completes a short hosted research task through an actual public documentation MCP server', :live do
    live_context = recorded_research_context
    job = live_context.research_later(
      'Use the Microsoft Learn MCP search tool for one lookup: what does Azure Functions do? ' \
      'Answer in one sentence with its source. Do not ask follow-up questions.',
      provider: :vertexai, agent:,
      server_tools: { mcp: { name: 'microsoft_learn', url: 'https://learn.microsoft.com/api/mcp',
                             allowed_tools: [{ tools: ['microsoft_docs_search'], mode: 'auto' }] } }
    )
    job.wait(timeout: 240, interval: 3)

    expect(job).to be_completed
    expect(job.message.content).not_to be_empty
    expect(job.message.citations.map(&:title)).to include('microsoft_docs_search result')
    expect(job.message.model).to be_nil
    expect(job.tokens.input).to be_positive
    expect(job.cost.total).to be_nil
  ensure
    job&.cancel if job&.pending?
  end

  it 'cancels an actual independently submitted hosted research task', :live do
    live_context = recorded_research_context
    job = live_context.research_later('Find the official Ruby documentation homepage.', provider: :vertexai, agent:)
    job.cancel
    job.refresh
    expect(job).to be_cancelled
  ensure
    job&.cancel if job&.pending?
  end

  def recorded_research_context
    recorder = Object.new
    recorder.define_singleton_method(:instrument) do |name, payload, &block|
      result = block&.call(payload)
      if name == 'request.ruby_llm' && payload[:method] == :post && payload[:url].end_with?('/interactions')
        body = result.body
        if body.is_a?(Hash) && body['id']
          File.open(File.join(Dir.tmpdir, 'ruby_llm_research_fixture_jobs.jsonl'), 'a') do |file|
            file.puts(JSON.generate(id: body['id'], agent: body['agent'], status: body['status'],
                                    at: Time.now.utc.iso8601))
            file.fsync
          end
        end
      end
      result
    end
    RubyLLM.context do |config|
      config.vertexai_location = 'global'
      config.instrumenter = recorder
    end
  end
end
