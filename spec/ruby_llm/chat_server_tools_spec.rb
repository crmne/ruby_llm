# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  describe '#with_server_tools' do
    it 'normalizes symbols, keywords, and raw hashes' do
      chat = RubyLLM.chat.with_server_tools(:web_search, { type: 'custom_tool' }, code_execution: { max_uses: 1 })

      expect(chat.server_tools).to eq(
        [
          { name: :web_search, options: {} },
          { raw: { type: 'custom_tool' } },
          { name: :code_execution, options: { max_uses: 1 } }
        ]
      )
    end

    it 'accumulates across calls and clears with nil' do
      chat = RubyLLM.chat.with_server_tools(:web_search).with_server_tools(:code_execution)

      expect(chat.server_tools.length).to eq(2)

      chat.with_server_tools(nil)

      expect(chat.server_tools).to be_empty
    end

    it 'rejects entries that are neither symbols nor hashes' do
      expect { RubyLLM.chat.with_server_tools(42) }.to raise_error(ArgumentError, /Symbols or Hashes/)
    end
  end

  describe 'request rendering' do
    it 'renders Anthropic aliases into versioned tool entries' do
      payload = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic)
                       .with_server_tools(:web_search, web_fetch: { max_uses: 2 })
                       .render

      expect(payload[:tools]).to include(
        { type: 'web_search_20260318', name: 'web_search', allowed_callers: ['direct'] }
      )
      expect(payload[:tools]).to include(
        { type: 'web_fetch_20260318', name: 'web_fetch', allowed_callers: ['direct'], max_uses: 2 }
      )
    end

    it 'passes raw tool hashes through verbatim' do
      raw_tool = { type: 'web_search_20250305', name: 'web_search', max_uses: 1 }
      payload = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic)
                       .with_server_tools(raw_tool)
                       .render

      expect(payload[:tools]).to include(raw_tool)
    end

    it 'keeps function tools alongside server tools' do
      weather = Class.new(RubyLLM::Tool) do
        def self.name = 'Weather'
        description 'Looks up weather'

        def execute(**) = 'sunny'
      end
      payload = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic)
                       .with_tools(weather)
                       .with_server_tools(:web_search)
                       .render

      expect(payload[:tools].length).to eq(2)
    end

    it 'expands the Anthropic MCP alias into servers, toolset, and beta header' do
      payload = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic)
                       .with_server_tools(mcp: { url: 'https://mcp.example.com', name: 'example' })
                       .render

      expect(payload[:mcp_servers]).to eq([{ type: 'url', name: 'example', url: 'https://mcp.example.com' }])
      expect(payload[:tools]).to include({ type: 'mcp_toolset', mcp_server_name: 'example' })
    end

    it 'renders OpenAI Responses aliases' do
      payload = RubyLLM.chat(model: 'gpt-5.2', provider: :openai)
                       .with_server_tools(:web_search, :code_execution)
                       .render

      expect(payload[:tools]).to include({ type: 'web_search' })
      expect(payload[:tools]).to include({ type: 'code_interpreter', container: { type: 'auto' } })
    end

    it 'renders Gemini aliases with options nested inside the tool key' do
      payload = RubyLLM.chat(model: 'gemini-3.5-flash', provider: :gemini)
                       .with_server_tools(:web_search, file_search: { file_search_store_names: ['store'] })
                       .render

      expect(payload[:tools]).to include({ google_search: {} })
      expect(payload[:tools]).to include({ file_search: { file_search_store_names: ['store'] } })
    end

    it 'renders xAI Responses aliases with passthrough options' do
      payload = RubyLLM.chat(model: 'grok-4.3', provider: :xai)
                       .with_server_tools(:x_search, :code_execution,
                                          web_search: { filters: { allowed_domains: ['ruby-lang.org'] } })
                       .render

      expect(payload[:input]).to be_an(Array)
      expect(payload[:tools]).to include({ type: 'x_search' })
      expect(payload[:tools]).to include({ type: 'code_execution' })
      expect(payload[:tools]).to include({ type: 'web_search', filters: { allowed_domains: ['ruby-lang.org'] } })
    end

    it 'renders the xAI MCP alias with server options' do
      payload = RubyLLM.chat(model: 'grok-4.3', provider: :xai)
                       .with_server_tools(mcp: { server_url: 'https://mcp.example.com/mcp', server_label: 'example' })
                       .render

      expect(payload[:tools]).to include(
        { type: 'mcp', server_url: 'https://mcp.example.com/mcp', server_label: 'example' }
      )
    end

    it 'renders DeepSeek aliases on the responses protocol' do
      payload = RubyLLM.chat(model: 'deepseek-v4-flash', provider: :deepseek, protocol: :responses)
                       .with_server_tools(:web_search, :apply_patch)
                       .render

      expect(payload[:tools]).to include({ type: 'web_search' })
      expect(payload[:tools]).to include({ type: 'custom', name: 'apply_patch' })
    end

    it 'renders Azure Responses aliases, which lack web_search' do
      payload = RubyLLM.chat(model: 'gpt-5-nano', provider: :azure, protocol: :responses)
                       .with_server_tools(:code_execution)
                       .render

      expect(payload[:input]).to be_an(Array)
      expect(payload[:tools]).to include({ type: 'code_interpreter', container: { type: 'auto' } })
    end

    it 'raises for web_search on Azure, which does not offer it' do
      chat = RubyLLM.chat(model: 'gpt-5-nano', provider: :azure, protocol: :responses)
                    .with_server_tools(:web_search)

      expect { chat.render }.to raise_error(RubyLLM::UnsupportedServerToolError, /:code_interpreter/)
    end

    it 'renders OpenRouter aliases as openrouter-prefixed tools' do
      payload = RubyLLM.chat(model: 'openai/gpt-5.2', provider: :openrouter)
                       .with_server_tools(:web_search)
                       .render

      expect(payload[:tools]).to include({ type: 'openrouter:web_search' })
    end

    it 'raises for unknown aliases and lists the known ones' do
      chat = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic).with_server_tools(:teleport)

      expect { chat.render }.to raise_error(RubyLLM::UnsupportedServerToolError, /:web_search/)
    end

    it 'raises for providers without server-tool support' do
      chat = RubyLLM.chat(model: 'deepseek-v4-flash', provider: :deepseek).with_server_tools(:web_search)

      expect { chat.render }.to raise_error(RubyLLM::UnsupportedServerToolError, /with_provider_options/)
    end
  end

  describe 'pause_turn merging' do
    it 'merges continuation segments into one message' do
      protocol = RubyLLM::Protocols::Anthropic.new(RubyLLM::Providers::Anthropic.new(RubyLLM.config))
      paused = RubyLLM::Message.new(
        role: :assistant, content: 'Searching. ', finish_reason: 'pause_turn',
        raw_content: [{ 'type' => 'server_tool_use', 'id' => 'srvtoolu_1', 'name' => 'web_search',
                        'input' => { 'query' => 'ruby' } }],
        server_tool_calls: [RubyLLM::ServerToolCall.new(type: 'server_tool_use', raw: {})],
        input_tokens: 10, output_tokens: 5
      )
      final = RubyLLM::Message.new(
        role: :assistant, content: 'Done.', finish_reason: 'end_turn',
        raw_content: [{ 'type' => 'text', 'text' => 'Done.' }],
        input_tokens: 20, output_tokens: 7, model: 'claude-haiku-4-5'
      )

      merged = protocol.send(:merge_turn_segments, [paused, final])

      expect(merged.content).to eq('Searching. Done.')
      expect(merged.finish_reason).to eq('end_turn')
      expect(merged.raw_content.length).to eq(2)
      expect(merged.server_tool_calls.length).to eq(1)
      expect(merged.tokens.input).to eq(30)
      expect(merged.tokens.output).to eq(12)
    end
  end

  describe 'web search' do
    context 'with anthropic/claude-haiku-4-5' do
      let(:chat) { RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic).with_server_tools(:web_search) }

      it 'searches, cites, and reports tool usage' do
        response = chat.ask('Search the web: what is the latest stable Ruby version? Cite your source.')

        expect(response.server_tool_calls).not_to be_empty
        expect(response.server_tool_calls.map(&:type)).to include('server_tool_use')
        expect(response.server_tool_calls.map(&:type)).to include('web_search_tool_result')
        expect(response.citations).not_to be_empty
        expect(response.tokens.server_tool_use).to include('web_search_requests')
        expect(response.raw_content).to be_an(Array)
      end

      it 'replays search turns so the conversation can continue' do
        chat.ask('Search the web: what is the latest stable Ruby version?')
        followup = chat.ask('Thanks. Now just say OK.')

        expect(followup.content).to be_present
      end

      it 'streams search turns and reconstructs them' do
        chunks = []
        response = chat.ask('Search the web: what is the latest stable Ruby version?') { |chunk| chunks << chunk }

        expect(chunks).not_to be_empty
        expect(response.server_tool_calls.map(&:type)).to include('server_tool_use')
        expect(response.raw_content).to be_an(Array)

        followup = chat.ask('Thanks. Now just say OK.')
        expect(followup.content).to be_present
      end
    end

    context 'with openai/gpt-5.2' do
      let(:chat) { RubyLLM.chat(model: 'gpt-5.2', provider: :openai).with_server_tools(:web_search) }

      it 'searches and records the tool call items' do
        response = chat.ask('Search the web: what is the latest stable Ruby version? Cite your source.')

        expect(response.server_tool_calls.map(&:type)).to include('web_search_call')
        expect(response.raw_content).to be_an(Array)

        followup = chat.ask('Thanks. Now just say OK.')
        expect(followup.content).to be_present
      end
    end

    context 'with gemini/gemini-3.5-flash' do
      let(:chat) { RubyLLM.chat(model: 'gemini-3.5-flash', provider: :gemini).with_server_tools(:web_search) }

      it 'grounds the answer and exposes the queries it ran' do
        response = chat.ask('Search the web: what is the latest stable Ruby version? Cite your source.')

        expect(response.server_tool_calls.map(&:type)).to include('google_search')
        expect(response.citations).not_to be_empty
      end
    end

    context 'with openrouter/openai/gpt-5.2' do
      let(:chat) { RubyLLM.chat(model: 'openai/gpt-5.2', provider: :openrouter).with_server_tools(:web_search) }

      it 'searches transparently, returning citations and usage counters' do
        response = chat.ask('Search the web: what is the latest stable Ruby version? Cite your source.')

        expect(response.citations).not_to be_empty
        expect(response.tokens.server_tool_use).to include('web_search_requests')
      end
    end

    context 'with xai/grok-4.3' do
      let(:chat) { RubyLLM.chat(model: 'grok-4.3', provider: :xai).with_server_tools(:web_search) }

      it 'searches, cites, and counts the sources it used' do
        response = chat.ask('Search the web: what is the latest stable Ruby version? Cite your source.')

        expect(response.server_tool_calls).not_to be_empty
        expect(response.citations).not_to be_empty
        expect(response.tokens.server_tool_use).to include('num_server_side_tools_used')
        expect(response.raw_content).to be_an(Array)
      end

      it 'replays search turns so the conversation can continue' do
        chat.ask('Search the web: what is the latest stable Ruby version?')
        followup = chat.ask('Thanks. Now just say OK.')

        expect(followup.content).to be_present
      end
    end

    context 'with deepseek/deepseek-v4-flash' do
      let(:chat) do
        RubyLLM.chat(model: 'deepseek-v4-flash', provider: :deepseek, protocol: :responses)
               .with_server_tools(:web_search)
      end

      it 'searches server-side and records the search turns' do
        response = chat.ask('Search the web: what is the latest stable Ruby version? Cite your source.')

        expect(response.server_tool_calls).not_to be_empty
        expect(response.raw_content).to be_an(Array)
        expect(response.content).to be_present
      end
    end
  end

  describe 'responses protocol dialects' do
    context 'with xai/grok-4.3' do
      it 'chats on the Responses endpoint by default' do
        chat = RubyLLM.chat(model: 'grok-4.3', provider: :xai)
        response = chat.ask('What is 2 + 2? Just the number.')

        expect(response.raw.env.url.path).to end_with('/responses')
        expect(response.content).to include('4')
        expect(response.thinking).to be_present

        followup = chat.ask('Now multiply that by 3. Just the number.')
        expect(followup.content).to include('12')
      end
    end

    context 'with azure/gpt-5-nano' do
      let(:chat) { RubyLLM.chat(model: 'gpt-5-nano', provider: :azure, protocol: :responses) }

      it 'chats on the openai/v1 responses endpoint' do
        response = chat.ask('What is 2 + 2? Just the number.')

        expect(response.raw.env.url.path).to end_with('/openai/v1/responses')
        expect(response.content).to include('4')
        expect(response.thinking&.signature).to be_present

        followup = chat.ask('Now multiply that by 3. Just the number.')
        expect(followup.content).to include('12')
      end

      it 'streams responses' do
        chunks = []
        response = chat.ask('What is 2 + 2? Just the number.') { |chunk| chunks << chunk }

        expect(chunks).not_to be_empty
        expect(response.content).to include('4')
      end

      it 'round-trips tool calls' do
        weather = Class.new(RubyLLM::Tool) do
          def self.name = 'Weather'
          description 'Gets current weather for a location'
          parameter :latitude, description: 'Latitude (e.g., 52.5200)'
          parameter :longitude, description: 'Longitude (e.g., 13.4050)'

          def execute(latitude:, longitude:)
            "Current weather at #{latitude}, #{longitude}: 15°C, Wind: 10 km/h"
          end
        end

        response = chat.with_tools(weather).ask("What's the weather at 52.5200, 13.4050?")

        expect(response.content).to include('15')
      end
    end

    context 'with deepseek/deepseek-v4-flash' do
      let(:chat) { RubyLLM.chat(model: 'deepseek-v4-flash', provider: :deepseek, protocol: :responses) }

      it 'chats with reasoning text on the opt-in Responses protocol' do
        response = chat.ask('What is 2 + 2? Just the number.')

        expect(response.raw.env.url.path).to end_with('/responses')
        expect(response.content).to include('4')
        expect(response.thinking&.text).to be_present
      end

      it 'streams reasoning deltas' do
        chunks = []
        response = chat.ask('What is 2 + 2? Just the number.') { |chunk| chunks << chunk }

        expect(chunks).not_to be_empty
        expect(chunks.any?(&:thinking)).to be true
        expect(response.content).to include('4')
      end
    end
  end

  describe 'code execution' do
    context 'with anthropic/claude-haiku-4-5' do
      let(:chat) { RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic).with_server_tools(:code_execution) }

      it 'runs code server-side and returns the result blocks' do
        response = chat.ask('Use code execution to compute 123456789 * 987654321 and report the exact product.')

        expect(response.server_tool_calls).not_to be_empty
        expect(response.content).to include('121932631112635269')
      end
    end

    context 'with gemini/gemini-3.5-flash' do
      let(:chat) { RubyLLM.chat(model: 'gemini-3.5-flash', provider: :gemini).with_server_tools(:code_execution) }

      it 'runs code server-side and replays the turn' do
        response = chat.ask('Use code execution to compute 123456789 * 987654321 and report the exact product.')

        expect(response.server_tool_calls.map(&:type)).to include('executable_code')
        expect(response.content).to include('121932631112635269')

        followup = chat.ask('Thanks. Now just say OK.')
        expect(followup.content).to be_present
      end
    end
  end
end
