# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ContentFilter do
  let(:prompt_filters) do
    { 'hate' => { 'filtered' => false, 'severity' => 'safe' },
      'jailbreak' => { 'filtered' => false, 'detected' => false },
      'custom_blocklists' => [] }
  end
  let(:completion_filters) do
    { 'hate' => { 'filtered' => true, 'severity' => 'medium' },
      'protected_material_text' => { 'filtered' => false, 'detected' => true } }
  end
  let(:expected) do
    [{ source: :prompt, category: 'hate', severity: 'safe', filtered: false },
     { source: :prompt, category: 'jailbreak', filtered: false, detected: false },
     { source: :completion, category: 'hate', severity: 'medium', filtered: true },
     { source: :completion, category: 'protected_material_text', filtered: false, detected: true }]
  end

  def verdicts(message)
    message.content_filters.map(&:to_h)
  end

  it 'reads the verdicts on a Responses API response' do
    body = {
      'status' => 'incomplete', 'incomplete_details' => { 'reason' => 'content_filter' }, 'output' => [],
      'content_filters' => [
        { 'blocked' => false, 'source_type' => 'prompt', 'content_filter_results' => prompt_filters },
        { 'blocked' => true, 'source_type' => 'completion', 'content_filter_results' => completion_filters }
      ]
    }

    message = RubyLLM::Protocols::Responses.allocate.send(:parse_completion_body, body, raw: nil)

    expect(message).to be_content_filtered
    expect(verdicts(message)).to eq(expected)
  end

  it 'reads them from the end of a streamed Responses API response' do
    response = { 'status' => 'completed', 'output' => [], 'content_filters' => [
      { 'source_type' => 'completion', 'content_filter_results' => completion_filters }
    ] }

    chunk = RubyLLM::Protocols::Responses.allocate.send(:build_chunk, { 'type' => 'response.completed',
                                                                        'response' => response })

    expect(verdicts(chunk)).to eq(expected.last(2))
  end

  it 'reads the verdicts on a Chat Completions response' do
    body = {
      'prompt_filter_results' => [{ 'prompt_index' => 0, 'content_filter_results' => prompt_filters }],
      'choices' => [{ 'finish_reason' => 'content_filter', 'message' => { 'role' => 'assistant', 'content' => nil },
                      'content_filter_results' => completion_filters }]
    }

    message = RubyLLM::Protocols::ChatCompletions.allocate.send(:parse_completion_body, body, raw: nil)

    expect(verdicts(message)).to eq(expected)
  end

  it 'reads them from a streamed Chat Completions chunk' do
    data = { 'choices' => [{ 'delta' => { 'content' => 'Hi' }, 'content_filter_results' => completion_filters }] }

    chunk = RubyLLM::Protocols::ChatCompletions.allocate.send(:build_chunk, data)

    expect(verdicts(chunk)).to eq(expected.last(2))
  end

  it "reads each custom blocklist's verdict" do
    results = { 'custom_blocklists' => [{ 'id' => 'names', 'filtered' => true },
                                        { 'id' => 'words', 'filtered' => false }] }
    body = { 'content_filters' => [{ 'source_type' => 'completion', 'content_filter_results' => results }] }

    filters = RubyLLM::Protocols::ChatCompletions::ContentFilters.parse_content_filters(body)

    expect(filters.map { |filter| [filter.category, filter.filtered?] })
      .to eq([['custom_blocklists', true], ['custom_blocklists', false]])
  end

  it 'leaves out what carries no verdict' do
    results = { 'custom_blocklists' => [{ 'id' => 'names' }, 'names'], 'profanity' => { 'details' => [] } }
    body = { 'content_filters' => [{ 'source_type' => 'completion', 'content_filter_results' => results }] }

    expect(RubyLLM::Protocols::ChatCompletions::ContentFilters.parse_content_filters(body)).to eq([])
  end

  it 'leaves out sources it does not know' do
    body = { 'content_filters' => [{ 'source_type' => 'tool', 'content_filter_results' => completion_filters }] }

    expect(RubyLLM::Protocols::ChatCompletions::ContentFilters.parse_content_filters(body)).to eq([])
  end

  it 'keeps a verdict that filtered when a stream judges the category again' do
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    filtered = described_class.new(source: :completion, category: 'hate', severity: 'medium', filtered: true)
    later = described_class.new(source: :completion, category: 'hate', severity: 'low')
    safe = described_class.new(source: :completion, category: 'violence', severity: 'safe')
    worse = described_class.new(source: :completion, category: 'violence', severity: 'low')

    [[filtered], [later, safe], [worse]].each do |filters|
      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: '', content_filters: filters))
    end

    expect(accumulator.to_message(nil).content_filters).to eq([filtered, worse])
  end

  it 'has no verdicts by default, and leaves them out of to_h' do
    verdict = { 'source' => 'completion', 'category' => 'hate', 'filtered' => true }
    message = RubyLLM::Message.new(role: :assistant, content: 'Hi', content_filters: [verdict])

    expect(message.content_filters.first).to be_filtered
    expect(message.to_h).not_to have_key(:content_filters)
    expect(RubyLLM::Message.new(role: :assistant, content: 'Hi').content_filters).to eq([])
  end
end
