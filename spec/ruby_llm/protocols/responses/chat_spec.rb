# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::Chat do
  let(:protocol) { RubyLLM::Protocols::Responses.allocate }
  let(:model) { instance_double(RubyLLM::Model, id: 'gpt-5-nano') }

  def render_payload(messages, tools: {}, stream: false, **options)
    protocol.send(:render_payload, messages, tools:, temperature: nil, model:, stream:, tool_prefs: nil, **options)
  end

  describe '#render_payload' do
    { RubyLLM::Providers::OpenAI => 'original', RubyLLM::Providers::XAI => 'high' }.each do |provider_class, detail|
      it "preserves #{detail} detail for #{provider_class} tool-returned images" do
        protocol.instance_variable_set(:@provider, provider_class.allocate)
        image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__),
                                        resolution: :original)
        message = RubyLLM::Message.new(role: :tool, content: 'Page image', tool_call_id: 'call_1', attachments: [image])

        payload = render_payload([message])

        expect(payload.dig(:input, 1, :content, 1, :detail)).to eq(detail)
      end
    end

    it 'runs stateless and replays encrypted reasoning' do
      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')])

      expect(payload[:store]).to be(false)
      expect(payload[:include]).to eq(['reasoning.encrypted_content'])
    end

    it 'asks for encrypted reasoning whatever the model is named' do
      %w[gpt-4.1-mini grok-4-fast-reasoning deepseek-reasoner prod-reasoner].each do |id|
        payload = protocol.send(
          :render_payload, [RubyLLM::Message.new(role: :user, content: 'hi')],
          tools: {}, temperature: nil, model: instance_double(RubyLLM::Model, id:), tool_prefs: nil
        )

        expect(payload[:include]).to eq(['reasoning.encrypted_content'])
      end
    end

    it 'turns system messages into instructions' do
      messages = [
        RubyLLM::Message.new(role: :system, content: 'Be brief.'),
        RubyLLM::Message.new(role: :user, content: 'hi')
      ]

      payload = render_payload(messages)

      expect(payload[:instructions]).to eq('Be brief.')
      expect(payload[:input]).to eq([{ role: 'user', content: 'hi' }])
    end

    it 'replays reasoning, tool calls, and tool outputs as items' do
      protocol.instance_variable_set(:@provider, RubyLLM::Providers::OpenAI.allocate)
      usage = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider: 'openai', model: 'gpt-5-nano',
                                                    status: :succeeded)
      messages = [
        RubyLLM::Message.new(role: :user, content: 'weather?'),
        RubyLLM::Message.new(
          role: :assistant,
          content: '',
          thinking: RubyLLM::Thinking.new(signature: 'ENCRYPTED'),
          tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {}) },
          usage_entries: [usage]
        ),
        RubyLLM::Message.new(role: :tool, content: 'Sunny', tool_call_id: 'call_1')
      ]

      payload = render_payload(messages)

      expect(payload[:input][1]).to eq({ type: 'reasoning', summary: [], encrypted_content: 'ENCRYPTED' })
      expect(payload[:input][2]).to eq({ type: 'function_call', call_id: 'call_1', name: 'weather',
                                         arguments: '{}' })
      expect(payload[:input][3]).to eq({ type: 'function_call_output', call_id: 'call_1', output: 'Sunny' })
    end

    it 'replays assistant text as output_text content' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'hi'),
        RubyLLM::Message.new(role: :assistant, content: 'Hello!', finish_reason: 'MAX_TOKENS')
      ]

      payload = render_payload(messages)

      expect(payload[:input][1]).to eq({ role: 'assistant', content: [{ type: 'output_text', text: 'Hello!' }] })
    end

    it 'sends assistant attachments in a user item after the assistant text' do
      protocol.instance_variable_set(:@provider, RubyLLM::Providers::OpenAI.allocate)
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__))
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Draw a boat'),
        RubyLLM::Message.new(role: :assistant, content: 'Here it is', attachments: [image])
      ]

      payload = render_payload(messages)

      expect(payload[:input][1]).to eq({ role: 'assistant', content: [{ type: 'output_text', text: 'Here it is' }] })
      expect(payload[:input][2][:role]).to eq('user')
      expect(payload[:input][2][:content].map { |part| part[:type] }).to eq(%w[input_text input_image])
      expect(payload[:input][2][:content].first[:text]).to eq('Attachments from the assistant:')
    end

    it 'keeps an assistant turn that only carries attachments' do
      protocol.instance_variable_set(:@provider, RubyLLM::Providers::OpenAI.allocate)
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__))
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Draw a boat'),
        RubyLLM::Message.new(role: :assistant, content: nil, attachments: [image])
      ]

      payload = render_payload(messages)

      expect(payload[:input].length).to eq(2)
      expect(payload[:input][1][:content].map { |part| part[:type] }).to eq(%w[input_text input_image])
    end

    it 'sends assistant attachments after the function calls of the same turn' do
      protocol.instance_variable_set(:@provider, RubyLLM::Providers::OpenAI.allocate)
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__))
      message = RubyLLM::Message.new(
        role: :assistant, content: '', attachments: [image],
        tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {}) }
      )

      payload = render_payload([message])

      expect(payload[:input].map { |item| item[:type] || item[:role] }).to eq(%w[function_call user])
    end

    it 'sends the phase stored on an assistant message with its edited text' do
      message = RubyLLM::Message.new(role: :assistant, content: 'Edited answer', phase: 'commentary')

      expect(render_payload([message])[:input])
        .to eq([{ role: 'assistant', content: [{ type: 'output_text', text: 'Edited answer' }], phase: 'commentary' }])
    end

    it 'uses flat non-strict function definitions' do
      tool = instance_double(RubyLLM::Tool, name: 'weather', description: 'Looks up weather',
                                            parameters_schema: { 'type' => 'object' }, provider_options: {})

      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')], tools: { weather: tool })

      expect(payload[:tools]).to eq([{
                                      type: 'function',
                                      name: 'weather',
                                      description: 'Looks up weather',
                                      parameters: { 'type' => 'object' },
                                      strict: false
                                    }])
    end

    it 'lets tools opt into strict mode via provider_options' do
      tool = instance_double(RubyLLM::Tool, name: 'weather', description: 'Looks up weather',
                                            parameters_schema: { 'type' => 'object' },
                                            provider_options: { strict: true })

      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')], tools: { weather: tool })

      expect(payload[:tools].first[:strict]).to be(true)
    end

    it 'renders structured output as a text format' do
      schema = { name: 'response', schema: { type: 'object' }, strict: true }

      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')], schema: schema)

      expect(payload[:text]).to eq({
                                     format: {
                                       type: 'json_schema',
                                       name: 'response',
                                       schema: { type: 'object' },
                                       strict: true
                                     }
                                   })
    end

    it 'maps thinking effort to reasoning' do
      thinking = RubyLLM::Thinking::Config.new(effort: 'low')

      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')], thinking: thinking)

      expect(payload[:reasoning]).to eq({ effort: 'low' })
    end

    it 'asks for a reasoning summary when display is summarized' do
      thinking = RubyLLM::Thinking::Config.new(effort: 'low', display: :summarized)

      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')], thinking: thinking)

      expect(payload[:reasoning]).to eq({ effort: 'low', summary: 'auto' })
    end

    it 'renders prompt cache params for any Responses-compatible provider' do
      payload = render_payload(
        [RubyLLM::Message.new(role: :user, content: 'hi')],
        caching: { key: 'repo:ruby_llm', ttl: '30m' }
      )

      expect(payload[:prompt_cache_key]).to eq('repo:ruby_llm')
      expect(payload[:prompt_cache_options]).to eq(ttl: '30m')
    end

    it 'translates deprecated retention into a prompt cache ttl' do
      allow(RubyLLM.logger).to receive(:warn)

      payload = render_payload(
        [RubyLLM::Message.new(role: :user, content: 'hi')],
        caching: { retention: '24h' }
      )

      expect(payload[:prompt_cache_options]).to eq(ttl: '24h')
      expect(RubyLLM.logger).to have_received(:warn).with(/retention: is deprecated/)
    end

    it 'marks cache boundaries without disabling implicit caching' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here,
        RubyLLM::Message.new(role: :user, content: 'hi')
      ]

      payload = render_payload(messages)

      expect(payload[:input].first[:content]).to eq(
        [{ type: 'input_text', text: 'Long context', prompt_cache_breakpoint: { mode: 'explicit' } }]
      )
      expect(payload[:input].last).to eq(role: 'user', content: 'hi')
      expect(payload).not_to have_key(:prompt_cache_options)
    end

    it 'preserves cache options alongside explicit boundaries' do
      message = RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here

      payload = render_payload([message], caching: { ttl: '30m' })

      expect(payload[:prompt_cache_options]).to eq(ttl: '30m')
      expect(payload.dig(:input, 0, :content, -1, :prompt_cache_breakpoint)).to eq(mode: 'explicit')
    end

    it 'sends cache-bounded system messages as input items' do
      messages = [
        RubyLLM::Message.new(role: :system, content: 'Stable instructions').cache_until_here,
        RubyLLM::Message.new(role: :user, content: 'hi')
      ]

      payload = render_payload(messages)

      expect(payload[:instructions]).to be_nil
      expect(payload[:input].first).to eq(
        role: 'system',
        content: [{ type: 'input_text', text: 'Stable instructions', prompt_cache_breakpoint: { mode: 'explicit' } }]
      )
    end

    it 'keeps unmarked system messages after the cache-bounded one they follow' do
      messages = [
        RubyLLM::Message.new(role: :system, content: 'Shared policy').cache_until_here,
        RubyLLM::Message.new(role: :system, content: 'Today is Monday.'),
        RubyLLM::Message.new(role: :user, content: 'hi')
      ]

      payload = render_payload(messages)

      expect(payload[:instructions]).to be_nil
      expect(payload[:input].map { |item| item[:role] }).to eq(%w[system system user])
      expect(payload.dig(:input, 0, :content, 0, :text)).to eq('Shared policy')
      expect(payload.dig(:input, 1, :content)).to eq('Today is Monday.')
    end

    it 'sends system messages ahead of the conversation they follow' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'hi'),
        RubyLLM::Message.new(role: :assistant, content: 'Hello!'),
        RubyLLM::Message.new(role: :user, content: 'again'),
        RubyLLM::Message.new(role: :system, content: 'Shared policy').cache_until_here
      ]

      payload = render_payload(messages)

      expect(payload[:input].map { |item| item[:role] }).to eq(%w[system user assistant user])
    end

    it 'keeps cache-bounded system messages ahead of a compaction' do
      compaction = RubyLLM::Message.new(
        role: :assistant, content: nil,
        raw_content: { 'object' => 'response.compaction', 'output' => [{ 'type' => 'compaction', 'id' => 'cmp_1' }] }
      )
      messages = [
        RubyLLM::Message.new(role: :system, content: 'Shared policy').cache_until_here,
        RubyLLM::Message.new(role: :user, content: 'old question'),
        compaction,
        RubyLLM::Message.new(role: :user, content: 'new question')
      ]

      payload = render_payload(messages)

      expect(payload[:input].map { |item| item[:role] || item['type'] }).to eq(%w[system compaction user])
    end
  end

  describe '#parse_completion_response' do
    def response_with(output, usage: {})
      instance_double(
        Faraday::Response,
        body: { 'model' => 'gpt-5-nano', 'output' => output, 'usage' => usage, 'status' => 'completed' }
      )
    end

    it 'joins output_text parts into content' do
      response = response_with([
                                 { 'type' => 'message',
                                   'content' => [{ 'type' => 'output_text', 'text' => 'Hello' },
                                                 { 'type' => 'output_text', 'text' => ' world' }] }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.content).to eq('Hello world')
      expect(message.model).to eq('gpt-5-nano')
    end

    it 'preserves web, file-search and container-file citations' do
      response = response_with([
                                 { 'type' => 'message', 'content' => [{
                                   'type' => 'output_text', 'text' => 'Ruby facts', 'annotations' => [
                                     { 'type' => 'url_citation', 'url' => 'https://ruby-lang.org',
                                       'title' => 'Ruby', 'start_index' => 0, 'end_index' => 4 },
                                     { 'type' => 'file_citation', 'file_id' => 'file_facts',
                                       'filename' => 'facts.pdf', 'index' => 0 },
                                     { 'type' => 'container_file_citation', 'container_id' => 'container_1',
                                       'file_id' => 'file_report', 'filename' => 'report.txt',
                                       'start_index' => 5, 'end_index' => 10 },
                                     { 'type' => 'file_path', 'file_id' => 'file_download', 'index' => 1 }
                                   ]
                                 }] }
                               ])

      citations = protocol.send(:parse_completion_response, response).citations

      expect(citations.length).to eq(3)
      expect(citations[0]).to have_attributes(url: 'https://ruby-lang.org', text: 'Ruby', source_id: nil)
      expect(citations[1]).to have_attributes(
        source_id: 'file_facts', title: 'facts.pdf', source_index: 0, start_index: nil, end_index: nil, url: nil
      )
      expect(citations[2]).to have_attributes(source_id: 'file_report', title: 'report.txt', text: 'facts')
    end

    it 'places citation spans against all preceding response text' do
      response = response_with([
                                 { 'type' => 'message',
                                   'content' => [{ 'type' => 'output_text', 'text' => 'Café. ' }] },
                                 { 'type' => 'message', 'content' => [
                                   { 'type' => 'output_text', 'text' => 'Read ' },
                                   { 'type' => 'output_text', 'text' => 'Ruby', 'annotations' => [
                                     { 'type' => 'url_citation', 'url' => 'https://ruby-lang.org',
                                       'start_index' => 0, 'end_index' => 4 }
                                   ] }
                                 ] }
                               ])

      message = protocol.send(:parse_completion_response, response)
      citation = message.citations.first

      expect(citation).to have_attributes(start_index: 11, end_index: 15, text: 'Ruby')
      expect(message.content[citation.start_index...citation.end_index]).to eq(citation.text)
    end

    it 'surfaces refusal parts as content' do
      response = response_with([
                                 { 'type' => 'message',
                                   'content' => [{ 'type' => 'refusal', 'refusal' => 'I cannot help with that.' }] }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.content).to eq('I cannot help with that.')
    end

    it 'parses function calls keyed by call_id' do
      response = response_with([
                                 { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather',
                                   'arguments' => '{"city":"Berlin"}' }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.tool_calls.keys).to eq(['call_1'])
      expect(message.tool_calls['call_1'].name).to eq('weather')
      expect(message.tool_calls['call_1'].arguments).to eq({ 'city' => 'Berlin' })
    end

    it 'reads null function-call arguments as none and refuses other values that are not objects' do
      parse = lambda do |arguments|
        body = { 'model' => 'gpt-5-nano', 'status' => 'completed',
                 'output' => [{ 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'now',
                                'arguments' => arguments }] }
        protocol.send(:parse_completion_response, instance_double(Faraday::Response, body:))
      end

      expect(parse.call('null').tool_calls['call_1'].arguments).to eq({})
      expect { parse.call('"x"') }.to raise_error(RubyLLM::ToolCallParseError)
    end

    it 'wraps malformed function-call arguments in a RubyLLM error' do
      response = instance_double(
        Faraday::Response,
        body: {
          'model' => 'gpt-5-nano',
          'output' => [
            { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather',
              'arguments' => '{"city":"Berlin"' }
          ],
          'status' => 'incomplete',
          'incomplete_details' => { 'reason' => 'max_output_tokens' }
        }
      )

      error = nil

      expect do
        protocol.send(:parse_completion_response, response)
      rescue RubyLLM::ToolCallParseError => e
        error = e
        raise
      end.to raise_error(RubyLLM::ToolCallParseError)

      expect(error).to be_a(RubyLLM::Error)
      expect(error.response).to eq(response)
      expect(error).to be_a(RubyLLM::ToolCallTruncatedError)
      expect(error.finish_reason).to eq(:max_tokens)
      expect(error.cause).to be_a(JSON::ParserError)
    end

    it 'parses reasoning summaries and encrypted content into thinking' do
      response = response_with([
                                 { 'type' => 'reasoning',
                                   'summary' => [{ 'type' => 'summary_text', 'text' => 'Thinking...' }],
                                   'encrypted_content' => 'ENCRYPTED' }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.thinking.text).to eq('Thinking...')
      expect(message.thinking.signature).to eq('ENCRYPTED')
    end

    it 'separates reasoning summary parts the way the stream does' do
      response = response_with([
                                 { 'type' => 'reasoning',
                                   'summary' => [{ 'type' => 'summary_text', 'text' => '**First summary**' },
                                                 { 'type' => 'summary_text', 'text' => '**Second summary**' }] }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.thinking.text).to eq("**First summary**\n\n**Second summary**")
    end

    it 'maps usage with cached and reasoning tokens' do
      response = response_with([], usage: {
                                 'input_tokens' => 10,
                                 'output_tokens' => 7,
                                 'input_tokens_details' => { 'cached_tokens' => 4 },
                                 'output_tokens_details' => { 'reasoning_tokens' => 3 }
                               })

      message = protocol.send(:parse_completion_response, response)

      expect(message.tokens.input).to eq(6)
      expect(message.tokens.output).to eq(7)
      expect(message.tokens.cache_read).to eq(4)
      expect(message.tokens.thinking).to eq(3)
    end

    it 'counts the web searches the response reports in tool_usage' do
      response = instance_double(Faraday::Response, body: {
                                   'model' => 'gpt-5.2', 'status' => 'completed', 'output' => [],
                                   'usage' => { 'input_tokens' => 8610, 'output_tokens' => 89 },
                                   'tool_usage' => {
                                     'image_gen' => { 'input_tokens' => 0, 'output_tokens' => 0, 'total_tokens' => 0 },
                                     'web_search' => { 'num_requests' => 2 }
                                   }
                                 })

      message = protocol.send(:parse_completion_response, response)

      expect(message.tokens.server_tool_use).to eq('web_search_requests' => 2)
    end

    it 'maps cache write tokens for models that bill cache writes' do
      response = response_with([], usage: {
                                 'input_tokens' => 2048,
                                 'output_tokens' => 7,
                                 'input_tokens_details' => { 'cached_tokens' => 1920, 'cache_write_tokens' => 100 }
                               })

      message = protocol.send(:parse_completion_response, response)

      expect(message.tokens.input).to eq(28)
      expect(message.tokens.cache_read).to eq(1920)
      expect(message.tokens.cache_write).to eq(100)
    end

    it 'reports a tool-call stop as finish_reason for function calls' do
      response = response_with([
                                 { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather',
                                   'arguments' => '{}' }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.finish_reason).to eq(:tool_calls)
      expect(message).to be_tool_call_stop
      expect(message).not_to be_stopped
    end

    it 'reports a normal stop when the provider ran every tool itself' do
      response = response_with([
                                 { 'type' => 'web_search_call', 'id' => 'ws_1', 'status' => 'completed' },
                                 { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => 'Done' }] }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.finish_reason).to eq(:stop)
      expect(message).to be_stopped
    end

    context 'with several reasoning items' do
      let(:output) do
        [
          { 'type' => 'reasoning', 'id' => 'rs_1', 'encrypted_content' => 'first',
            'summary' => [{ 'type' => 'summary_text', 'text' => 'Plan' }] },
          { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => 'Checking.' }] },
          { 'type' => 'reasoning', 'id' => 'rs_2', 'encrypted_content' => 'second', 'summary' => [] },
          { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather', 'arguments' => '{}' }
        ]
      end

      it 'keeps the raw output so each one replays with its own encrypted content' do
        message = protocol.send(:parse_completion_response, response_with(output))

        expect(message.raw_content).to eq(output)
        expect(protocol.send(:render_input, [message])).to eq(output)
      end

      it 'keeps no raw output for a single reasoning item' do
        message = protocol.send(:parse_completion_response, response_with(output.first(2)))

        expect(message.raw_content).to be_nil
      end
    end

    context 'with a phased assistant message' do
      before { protocol.instance_variable_set(:@provider, RubyLLM::Providers::OpenAI.allocate) }

      let(:output) do
        [
          { 'type' => 'reasoning', 'id' => 'rs_1', 'encrypted_content' => 'only', 'summary' => [] },
          { 'type' => 'message', 'id' => 'msg_1', 'role' => 'assistant', 'status' => 'completed',
            'phase' => 'final_answer', 'content' => [{ 'type' => 'output_text', 'text' => 'Done.' }] }
        ]
      end

      it 'keeps the phase on the message and sends it back with the rebuilt turn' do
        message = protocol.send(:parse_completion_response, response_with(output))

        expect(message.phase).to eq('final_answer')
        expect(message.raw_content).to be_nil
        expect(protocol.send(:render_input, [message]).last)
          .to eq(role: 'assistant', content: [{ type: 'output_text', text: 'Done.' }], phase: 'final_answer')
      end

      it 'keeps no phase when the provider sends a null one' do
        output.last['phase'] = nil

        message = protocol.send(:parse_completion_response, response_with(output))

        expect(message.phase).to be_nil
        expect(protocol.send(:render_input, [message]).last).not_to have_key(:phase)
      end

      it 'keeps the raw output when its messages carry different phases' do
        phased = output.insert(1, output.last.merge('id' => 'msg_0', 'phase' => 'commentary'))

        message = protocol.send(:parse_completion_response, response_with(phased))

        expect(message.raw_content).to eq(phased)
      end

      it 'keeps the raw output when only some of its messages carry a phase' do
        phased = output.insert(1, output.last.merge('id' => 'msg_0', 'phase' => nil))

        message = protocol.send(:parse_completion_response, response_with(phased))

        expect(message.raw_content).to eq(phased)
        expect(message.phase).to eq('final_answer')
      end

      it 'parses structured output from the final answer only, keeping the commentary in content' do
        output.last['content'].first['text'] = '{"total":12.1}'
        commentary = output.last.merge('id' => 'msg_0', 'phase' => 'commentary',
                                       'content' => [{ 'type' => 'output_text', 'text' => 'Reading the total.' }])

        message = protocol.send(:parse_completion_response, response_with(output.insert(1, commentary)))

        expect(message.content).to eq('Reading the total.{"total":12.1}')
        expect(message.parsed).to eq('total' => 12.1)
      end

      it 'parses nothing when no message is a final answer' do
        output.last['phase'] = 'commentary'

        message = protocol.send(:parse_completion_response, response_with(output))

        expect(message.content).to eq('Done.')
        expect(message.parsed).to be_nil
      end

      it 'parses every message when none carries a phase' do
        output.last['phase'] = nil
        output.last['content'].first['text'] = '{"total":'
        output << output.last.merge('id' => 'msg_2', 'content' => [{ 'type' => 'output_text', 'text' => '12.1}' }])

        message = protocol.send(:parse_completion_response, response_with(output))

        expect(message.parsed).to eq('total' => 12.1)
      end
    end

    it 'preserves incomplete_details reason as finish_reason when present' do
      response = instance_double(
        Faraday::Response,
        body: {
          'model' => 'gpt-5-nano',
          'output' => [],
          'status' => 'incomplete',
          'incomplete_details' => { 'reason' => 'max_output_tokens' }
        }
      )

      message = protocol.send(:parse_completion_response, response)

      expect(message.finish_reason).to eq(:max_tokens)
    end
  end
end
