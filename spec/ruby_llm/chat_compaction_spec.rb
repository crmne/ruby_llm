# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  def render_with_compaction(model:, provider:, protocol: nil, **options)
    RubyLLM.chat(model: model, provider: provider, protocol: protocol)
           .with_compaction(**options)
           .ask_later('Hello')
           .render
  end

  describe '#with_compaction' do
    it 'returns self and remembers the options' do
      chat = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic)

      expect(chat.with_compaction(at: 50_000)).to be(chat)
      expect(chat.compaction).to eq(at: 50_000)
    end

    it 'enables the provider default when given no options' do
      chat = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic).with_compaction

      expect(chat.compaction).to eq({})
    end

    it 'clears the options when given nil' do
      chat = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic).with_compaction(at: 50_000)

      expect(chat.with_compaction(nil).compaction).to be_nil
    end

    it 'names the portable options when given one it does not have' do
      chat = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic)

      expect { chat.with_compaction(compact_threshold: 50_000) }
        .to raise_error(ArgumentError, /:at, :instructions, :pause_after.*:compact_threshold/m)
    end

    it 'sends nothing when compaction is off' do
      payload = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic).ask_later('Hello').render

      expect(payload).not_to have_key(:context_management)
    end
  end

  describe 'provider mapping' do
    it 'maps to a context_management edit on Anthropic' do
      payload = render_with_compaction(model: 'claude-haiku-4-5', provider: :anthropic, at: 50_000)

      expect(payload[:context_management]).to eq(
        edits: [{ type: 'compact_20260112', trigger: { type: 'input_tokens', value: 50_000 } }]
      )
    end

    it 'leaves the Anthropic trigger to the API when no threshold is given' do
      payload = render_with_compaction(model: 'claude-haiku-4-5', provider: :anthropic)

      expect(payload.dig(:context_management, :edits)).to eq([{ type: 'compact_20260112' }])
    end

    it 'carries instructions and pause_after into the Anthropic edit' do
      payload = render_with_compaction(model: 'claude-haiku-4-5', provider: :anthropic,
                                       at: 50_000, instructions: 'Keep every decision.', pause_after: true)

      expect(payload.dig(:context_management, :edits, 0)).to include(
        instructions: 'Keep every decision.',
        pause_after_compaction: true
      )
    end

    it 'maps to a compact_threshold entry on the OpenAI Responses API' do
      payload = render_with_compaction(model: 'gpt-5-nano', provider: :openai, protocol: :responses, at: 200_000)

      expect(payload[:context_management]).to eq([{ type: 'compaction', compact_threshold: 200_000 }])
    end

    it 'omits the OpenAI threshold when no threshold is given' do
      payload = render_with_compaction(model: 'gpt-5-nano', provider: :openai, protocol: :responses)

      expect(payload[:context_management]).to eq([{ type: 'compaction' }])
    end

    it 'maps to a compact_threshold entry on Azure Responses' do
      payload = render_with_compaction(model: 'gpt-5-nano', provider: :azure, protocol: :responses, at: 200_000)

      expect(payload[:context_management]).to eq([{ type: 'compaction', compact_threshold: 200_000 }])
    end

    it 'maps to the context-compression plugin on OpenRouter' do
      payload = render_with_compaction(model: 'claude-haiku-4-5', provider: :openrouter)

      expect(payload[:plugins]).to eq([{ id: 'context-compression' }])
    end

    it 'drops compaction for providers that manage context themselves' do
      payload = render_with_compaction(model: 'gemini-2.5-flash', provider: :gemini, at: 50_000)

      expect(payload.to_s).not_to include('compact')
    end

    it 'drops compaction on Responses services that do not serve the parameter' do
      payload = render_with_compaction(model: 'grok-4-1-fast-non-reasoning', provider: :xai,
                                       protocol: :responses, at: 50_000)

      expect(payload).not_to have_key(:context_management)
    end

    it 'drops compaction on Chat Completions' do
      payload = render_with_compaction(model: 'gpt-5-nano', provider: :openai,
                                       protocol: :chat_completions, at: 50_000)

      expect(payload).not_to have_key(:context_management)
    end

    it 'lets provider options override the mapped value' do
      payload = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic)
                       .with_compaction(at: 50_000)
                       .with_provider_options(context_management: { edits: [] })
                       .ask_later('Hello')
                       .render

      expect(payload.dig(:context_management, :edits)).to eq([])
    end
  end

  describe 'anthropic claude-sonnet-4-6', :live do
    # Compaction only runs on a conversation big enough to cross the
    # threshold, so the filler is generated rather than checked in.
    let(:notes) { 'The quick brown fox jumps over the lazy dog. ' * 9000 }

    it 'compacts a long conversation and bills the summarization pass' do
      chat = RubyLLM.chat(model: 'claude-sonnet-4-6', provider: :anthropic).with_compaction(at: 50_000)

      response = chat.ask("Here are my notes:\n#{notes}\nIn one sentence, which animal jumps in my notes?")

      compaction = response.server_tool_calls.find { |call| call.type == 'compaction' }
      expect(compaction).not_to be_nil
      expect(compaction.result).to be_a(String)
      expect(compaction.result).not_to be_empty
      expect(response.content).to include('fox')
      expect(response.raw_content.first['type']).to eq('compaction')
      expect(response.tokens.input).to be > 50_000
      expect(response.raw.body.dig('usage', 'input_tokens')).to be < response.tokens.input
    end
  end

  describe 'request headers' do
    let(:anthropic) { RubyLLM::Protocols::Anthropic.new(RubyLLM::Providers::Anthropic.new(RubyLLM.config)) }

    it 'asks Anthropic for the compaction beta' do
      headers = anthropic.send(:apply_compaction_headers, {}, { at: 50_000 })

      expect(headers['anthropic-beta']).to eq('compact-2026-01-12')
    end

    it 'keeps betas another feature already asked for' do
      headers = anthropic.send(:apply_compaction_headers, { 'anthropic-beta' => 'mcp-client-2025-11-20' }, {})

      expect(headers['anthropic-beta']).to eq('mcp-client-2025-11-20,compact-2026-01-12')
    end

    it 'asks for the beta once when it is already there' do
      headers = anthropic.send(:apply_compaction_headers, { 'anthropic-beta' => 'compact-2026-01-12' }, {})

      expect(headers['anthropic-beta']).to eq('compact-2026-01-12')
    end

    it 'leaves headers alone for protocols with no compaction beta' do
      openai = RubyLLM::Protocols::Responses.new(RubyLLM::Providers::OpenAI.new(RubyLLM.config))

      expect(openai.send(:apply_compaction_headers, { 'x-test' => '1' }, {})).to eq('x-test' => '1')
    end
  end
end
