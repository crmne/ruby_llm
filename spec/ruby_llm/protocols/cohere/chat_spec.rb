# frozen_string_literal: true

require 'spec_helper'

# Response fixtures are the examples published at
# https://docs.cohere.com/reference/chat, copied verbatim.
RSpec.describe RubyLLM::Protocols::Cohere::Chat do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::Cohere.new(RubyLLM.config) }
  let(:model) { RubyLLM.models.find(model_for(:cohere, :vision)) }
  let(:protocol) { RubyLLM::Protocols::Cohere.new(provider, model) }
  let(:reasoning_model) { RubyLLM.models.find(model_for(:cohere, :thinking)) }

  def render(messages, **options)
    protocol.send(
      :render_payload,
      messages,
      tools: {}, temperature: nil, model: model, stream: false, **options
    )
  end

  def user(content, attachments: [])
    RubyLLM::Message.new(role: :user, content: content, attachments: attachments)
  end

  describe '#completion_url' do
    it 'posts to the v2 chat endpoint' do
      expect(protocol.send(:completion_url)).to eq('v2/chat')
    end
  end

  describe '#render_payload' do
    it 'renders roles with content blocks' do
      payload = render(
        [RubyLLM::Message.new(role: :system, content: 'Be brief.'), user('Tell me about LLMs')]
      )

      expect(payload).to eq(
        model: 'command-a-plus-05-2026',
        messages: [
          { role: 'system', content: [{ type: 'text', text: 'Be brief.' }] },
          { role: 'user', content: [{ type: 'text', text: 'Tell me about LLMs' }] }
        ],
        stream: false
      )
    end

    it 'renders sampling and length controls' do
      payload = render([user('Hi')], temperature: 0.2, max_output_tokens: 512)

      expect(payload).to include(temperature: 0.2, max_tokens: 512)
    end

    it 'omits temperature when the request leaves it unset' do
      expect(render([user('Hi')])).not_to have_key(:temperature)
    end

    it 'renders a bare JSON schema under json_schema' do
      schema = { name: 'person', strict: true, schema: { type: 'object', properties: { name: { type: 'string' } } } }

      payload = render([user('Generate a JSON person')], schema: schema)

      expect(payload[:response_format]).to eq(
        type: 'json_object',
        json_schema: { type: 'object', properties: { name: { type: 'string' } } }
      )
    end

    it 'enables thinking with a token budget' do
      payload = protocol.send(
        :render_payload, [user('Hi')],
        tools: {}, temperature: nil, model: reasoning_model,
        thinking: RubyLLM::Thinking::Config.new(budget: 500)
      )

      expect(payload[:thinking]).to eq(type: 'enabled', token_budget: 500)
    end

    it 'disables the default reasoning of thinking models' do
      payload = protocol.send(
        :render_payload, [user('Hi')],
        tools: {}, temperature: nil, model: reasoning_model,
        thinking: RubyLLM::Thinking::Config.new(effort: :none)
      )

      expect(payload[:thinking]).to eq(type: 'disabled')
    end

    it 'sends thinking on models the registry does not list as reasoning models' do
      payload = protocol.send(
        :render_payload, [user('Hi')],
        tools: {}, temperature: nil, model: RubyLLM.models.find(model_for(:cohere)),
        thinking: RubyLLM::Thinking::Config.new(budget: 500)
      )

      expect(payload[:thinking]).to eq(type: 'enabled', token_budget: 500)
    end

    it 'lifts text attachments into documents when citations are on' do
      message = user('Who created Ruby?', attachments: [File.expand_path('../../../fixtures/facts.txt', __dir__)])

      payload = render([message], citations: true)

      expect(payload[:documents]).to contain_exactly(
        hash_including(id: 'doc:0', data: hash_including(title: 'facts.txt'))
      )
      expect(payload[:messages].first[:content]).to eq([{ type: 'text', text: 'Who created Ruby?' }])
    end

    it 'inlines text attachments when citations are off' do
      message = user('Who created Ruby?', attachments: [File.expand_path('../../../fixtures/facts.txt', __dir__)])

      payload = render([message])

      expect(payload).not_to have_key(:documents)
      expect(payload[:messages].first[:content].length).to eq(2)
    end
  end

  describe '#parse_completion_body' do
    let(:body) do
      {
        'id' => 'c14c80c3-18eb-4519-9460-6c92edd8cfb4',
        'finish_reason' => 'COMPLETE',
        'message' => {
          'role' => 'assistant',
          'content' => [{ 'type' => 'text', 'text' => 'LLMs stand for Large Language Models.' }]
        },
        'usage' => {
          'billed_units' => { 'input_tokens' => 5, 'output_tokens' => 418 },
          'tokens' => { 'input_tokens' => 71, 'output_tokens' => 418 }
        }
      }
    end

    it 'builds an assistant message from the response' do
      message = protocol.send(:parse_completion_body, body, raw: nil)

      expect(message.role).to eq(:assistant)
      expect(message.content).to eq('LLMs stand for Large Language Models.')
      expect(message.finish_reason).to eq(:stop)
      expect(message).to be_stopped
    end

    it 'reports the units Cohere bills, not the tokens the model processed' do
      message = protocol.send(:parse_completion_body, body, raw: nil)

      expect(message.tokens.input).to eq(5)
      expect(message.tokens.output).to eq(418)
      expect(message.tokens.thinking).to be_nil
    end

    it 'reports reasoning tokens without changing the billed units or cost' do
      body['usage'] = {
        'billed_units' => { 'input_tokens' => 26, 'output_tokens' => 165 },
        'tokens' => { 'input_tokens' => 1431, 'output_tokens' => 170, 'reasoning_tokens' => 143 },
        'cached_tokens' => 1344
      }
      billed_cost = model.cost_for(RubyLLM::Tokens.new(input: 26, output: 165))

      message = protocol.send(:parse_completion_body, body, raw: nil)

      expect(message.tokens).to have_attributes(input: 26, output: 165, thinking: 143, cache_read: nil)
      expect(message.cost.to_h).to eq(billed_cost.to_h)
    end

    it 'preserves an explicitly reported zero reasoning count' do
      body['usage']['tokens']['reasoning_tokens'] = 0

      expect(protocol.send(:parse_completion_body, body, raw: nil).tokens.thinking).to eq(0)
    end

    it 'names the requested model, which the response body omits' do
      expect(protocol.send(:parse_completion_body, body, raw: nil).model).to eq('command-a-plus-05-2026')
    end

    context 'when the reply hit the prompt cache' do
      before do
        body['usage'] = { 'billed_units' => { 'input_tokens' => 8, 'output_tokens' => 8 },
                          'tokens' => { 'input_tokens' => 503, 'output_tokens' => 11 }, 'cached_tokens' => 448 }
      end

      it 'reports the billed units without the cache hits Cohere does not bill' do
        message = protocol.send(:parse_completion_body, body, raw: nil)

        expect(message.tokens).to have_attributes(input: 8, output: 8, cache_read: nil)
      end

      it 'has a cost, which is what Cohere bills for it' do
        message = protocol.send(:parse_completion_body, body, raw: nil)

        expect(message.cost.total).to be_within(0.0000001).of(0.0001)
      end
    end

    it 'raises a generation that ended in an error' do
      body['finish_reason'] = 'ERROR'

      expect { protocol.send(:parse_completion_body, body, raw: nil) }
        .to raise_error(RubyLLM::ServerError, 'The generation failed due to an internal error')
    end
  end

  describe 'thinking and tool calls' do
    let(:body) do
      {
        'id' => '9e5f00aa-bf1e-481a-abe3-0eceac18c3ec',
        'finish_reason' => 'TOOL_CALL',
        'message' => {
          'role' => 'assistant',
          'tool_calls' => [
            {
              'id' => 'query_daily_sales_report_hgxxmkby3wta',
              'type' => 'function',
              'function' => { 'name' => 'query_daily_sales_report', 'arguments' => '{"day": "2023-09-29"}' }
            }
          ],
          'content' => [
            { 'type' => 'thinking', 'thinking' => 'I will first find the sales summary for 29th September 2023.' }
          ]
        }
      }
    end

    it 'parses tool calls keyed by id' do
      message = protocol.send(:parse_completion_body, body, raw: nil)

      expect(message.tool_calls.keys).to eq(['query_daily_sales_report_hgxxmkby3wta'])
      expect(message.tool_calls.values.first).to have_attributes(
        name: 'query_daily_sales_report',
        arguments: { 'day' => '2023-09-29' }
      )
      expect(message).to be_tool_call_stop
    end

    it 'parses thinking blocks' do
      message = protocol.send(:parse_completion_body, body, raw: nil)

      expect(message.thinking.text).to eq('I will first find the sales summary for 29th September 2023.')
    end

    it 'falls back to the tool plan when there is no thinking block' do
      body['message'].delete('content')
      body['message']['tool_plan'] = 'I will use the query_daily_sales_report tool.'

      message = protocol.send(:parse_completion_body, body, raw: nil)

      expect(message.thinking.text).to eq('I will use the query_daily_sales_report tool.')
    end
  end

  describe 'citations' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:content) do
      'Both NSync and Backstreet Boys were extremely popular at the turn of the millennium. ' \
        'Backstreet Boys had massive album sales across the globe.'
    end

    let(:body) do
      {
        'id' => 'c14c80c3-18eb-4519-9460-6c92edd8cfb4',
        'finish_reason' => 'COMPLETE',
        'message' => {
          'role' => 'assistant',
          'content' => [{ 'type' => 'text', 'text' => content }],
          'citations' => [
            {
              'start' => 36,
              'end' => 84,
              'text' => 'extremely popular at the turn of the millennium.',
              'sources' => [
                {
                  'type' => 'document',
                  'document' => {
                    'snippet' => 'At the turn of the millennium three teen acts were huge in the US.',
                    'title' => 'CSPC: NSYNC Popularity Analysis - ChartMasters',
                    'url' => 'https://chartmasters.org/nsync'
                  },
                  'id' => 'doc:1'
                }
              ]
            }
          ]
        }
      }
    end

    it 'maps citations onto spans of the response content' do
      message = protocol.send(:parse_completion_body, body, raw: nil)
      citation = message.citations.first

      expect(message.content[citation.start_index...citation.end_index]).to eq(citation.text)
    end

    it 'normalizes the cited source' do
      citation = protocol.send(:parse_completion_body, body, raw: nil).citations.first

      expect(citation).to have_attributes(
        title: 'CSPC: NSYNC Popularity Analysis - ChartMasters',
        cited_text: 'At the turn of the millennium three teen acts were huge in the US.',
        url: 'https://chartmasters.org/nsync',
        source_index: 1
      )
    end

    it 'accepts URL schemes regardless of case' do
      body['message']['citations'].first['sources'].first['document']['url'] = 'HTTPS://example.com/source'

      citation = protocol.send(:parse_completion_body, body, raw: nil).citations.first

      expect(citation.url).to eq('HTTPS://example.com/source')
    end

    it 'keeps the id of a cited tool output as its source_id' do
      body['message']['citations'].first['sources'] = [
        { 'type' => 'tool', 'id' => 'gid://app/Document/42',
          'tool_output' => { 'title' => 'Q4 Report', 'text' => 'Revenue grew 12%.', 'url' => 'https://example.com/q4' } }
      ]

      citation = protocol.send(:parse_completion_body, body, raw: nil).citations.first

      expect(citation).to have_attributes(
        url: 'https://example.com/q4', source_id: 'gid://app/Document/42', title: 'Q4 Report'
      )
    end

    it 'leaves source_id unset for cited documents' do
      citation = protocol.send(:parse_completion_body, body, raw: nil).citations.first

      expect(citation.source_id).to be_nil
      expect(citation.source_index).to eq(1)
    end

    it 'offsets spans by the text blocks that came before' do
      body['message']['content'].unshift({ 'type' => 'text', 'text' => 'Answer: ' })
      body['message']['citations'].first['content_index'] = 1

      message = protocol.send(:parse_completion_body, body, raw: nil)
      citation = message.citations.first

      expect(message.content[citation.start_index...citation.end_index]).to eq(citation.text)
    end

    it 'leaves thinking citations without a span into the content' do
      body['message']['citations'].first['type'] = 'THINKING_CONTENT'

      citation = protocol.send(:parse_completion_body, body, raw: nil).citations.first

      expect(citation.start_index).to be_nil
      expect(citation.end_index).to be_nil
      expect(citation.text).to eq('extremely popular at the turn of the millennium.')
    end
  end
end
