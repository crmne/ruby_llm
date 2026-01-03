# frozen_string_literal: true

require 'spec_helper'

# Extended Thinking is a cross-cutting feature that spans multiple classes.
# This spec file tests the feature holistically rather than per-class.
# rubocop:disable RSpec/MultipleDescribes

# Models with reasoning capability for integration tests
# Note: Grok via OpenRouter doesn't expose reasoning_content, so it's not included
THINKING_MODELS = [
  { provider: :anthropic, model: 'claude-sonnet-4-20250514' },
  { provider: :anthropic, model: 'claude-opus-4-20250514' },
  { provider: :anthropic, model: 'claude-opus-4-5-20251101' },
  { provider: :gemini, model: 'gemini-2.5-flash' }
].freeze

RSpec.describe RubyLLM::Message do
  include_context 'with configured RubyLLM'

  describe 'thinking attribute' do
    it 'stores thinking content' do
      message = described_class.new(
        role: :assistant,
        content: 'The answer is 42',
        thinking: 'Let me calculate this carefully...'
      )

      expect(message.thinking).to eq('Let me calculate this carefully...')
    end

    it 'can be nil when not present' do
      message = described_class.new(
        role: :assistant,
        content: 'The answer is 42'
      )

      expect(message.thinking).to be_nil
    end

    it 'includes thinking in to_h output' do
      message = described_class.new(
        role: :assistant,
        content: 'The answer is 42',
        thinking: 'Let me calculate this carefully...'
      )

      hash = message.to_h

      expect(hash[:thinking]).to eq('Let me calculate this carefully...')
      expect(hash[:content]).to eq('The answer is 42')
      expect(hash[:role]).to eq(:assistant)
    end

    it 'excludes thinking from to_h when nil' do
      message = described_class.new(
        role: :assistant,
        content: 'The answer is 42'
      )

      hash = message.to_h

      expect(hash).not_to have_key(:thinking)
    end

    it 'stores thinking_signature as protected attribute' do
      message = described_class.new(
        role: :assistant,
        content: 'Response',
        thinking: 'Thoughts',
        thinking_signature: 'sig-abc123'
      )

      expect(message.respond_to?(:thinking_signature, true)).to be true
      expect { message.thinking_signature }.to raise_error(NoMethodError)
    end
  end
end

RSpec.describe RubyLLM::Messages do
  include_context 'with configured RubyLLM'

  describe '.signature_for' do
    it 'returns thinking_signature when present' do
      message = RubyLLM::Message.new(
        role: :assistant,
        content: 'Response',
        thinking: 'Thoughts',
        thinking_signature: 'sig-xyz789'
      )

      signature = described_class.signature_for(message)

      expect(signature).to eq('sig-xyz789')
    end

    it 'returns nil when thinking_signature is not present' do
      message = RubyLLM::Message.new(
        role: :assistant,
        content: 'Response',
        thinking: 'Thoughts'
      )

      signature = described_class.signature_for(message)

      expect(signature).to be_nil
    end

    it 'returns nil for messages without thinking' do
      message = RubyLLM::Message.new(
        role: :assistant,
        content: 'Response'
      )

      signature = described_class.signature_for(message)

      expect(signature).to be_nil
    end

    it 'handles non-message objects gracefully' do
      object = Object.new

      signature = described_class.signature_for(object)

      expect(signature).to be_nil
    end
  end
end

RSpec.describe RubyLLM::StreamAccumulator do
  include_context 'with configured RubyLLM'

  describe 'thinking accumulation' do
    it 'accumulates thinking from multiple chunks' do
      accumulator = described_class.new

      chunk1 = RubyLLM::Chunk.new(
        role: :assistant,
        content: 'First ',
        thinking: 'Let me think... ',
        model_id: 'claude-sonnet-4-20250514'
      )
      chunk2 = RubyLLM::Chunk.new(
        role: :assistant,
        content: 'second',
        thinking: 'about this problem',
        model_id: 'claude-sonnet-4-20250514'
      )

      accumulator.add(chunk1)
      accumulator.add(chunk2)

      expect(accumulator.thinking).to eq('Let me think... about this problem')
      expect(accumulator.content).to eq('First second')
    end

    it 'returns empty string for thinking when no chunks have thinking' do
      accumulator = described_class.new

      chunk = RubyLLM::Chunk.new(
        role: :assistant,
        content: 'Regular response',
        model_id: 'claude-sonnet-4-20250514'
      )

      accumulator.add(chunk)

      expect(accumulator.thinking).to eq('')
    end

    it 'preserves thinking_signature from chunks' do
      accumulator = described_class.new

      chunk1 = RubyLLM::Chunk.new(
        role: :assistant,
        content: 'Response',
        thinking: 'Thinking',
        thinking_signature: 'sig-first',
        model_id: 'claude-sonnet-4-20250514'
      )
      chunk2 = RubyLLM::Chunk.new(
        role: :assistant,
        content: ' more',
        thinking: ' more',
        model_id: 'claude-sonnet-4-20250514'
      )

      accumulator.add(chunk1)
      accumulator.add(chunk2)

      # Build a mock response object for to_message
      mock_env = Struct.new(:request_body).new('{}')
      mock_response = Struct.new(:headers, :body, :status, :env).new({}, {}, 200, mock_env)
      message = accumulator.to_message(mock_response)

      expect(RubyLLM::Messages.signature_for(message)).to eq('sig-first')
    end

    it 'converts empty thinking to nil in message' do
      accumulator = described_class.new

      chunk = RubyLLM::Chunk.new(
        role: :assistant,
        content: 'Response',
        model_id: 'claude-sonnet-4-20250514'
      )

      accumulator.add(chunk)

      mock_env = Struct.new(:request_body).new('{}')
      mock_response = Struct.new(:headers, :body, :status, :env).new({}, {}, 200, mock_env)
      message = accumulator.to_message(mock_response)

      expect(message.thinking).to be_nil
    end

    it 'preserves non-empty thinking in message' do
      accumulator = described_class.new

      chunk = RubyLLM::Chunk.new(
        role: :assistant,
        content: 'Answer',
        thinking: 'Internal reasoning',
        model_id: 'claude-sonnet-4-20250514'
      )

      accumulator.add(chunk)

      mock_env = Struct.new(:request_body).new('{}')
      mock_response = Struct.new(:headers, :body, :status, :env).new({}, {}, 200, mock_env)
      message = accumulator.to_message(mock_response)

      expect(message.thinking).to eq('Internal reasoning')
    end
  end
end

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#with_thinking configuration' do
    THINKING_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]

      context "with #{provider}/#{model}" do
        it 'returns self for method chaining' do
          chat = RubyLLM.chat(model: model, provider: provider)
          result = chat.with_thinking(budget: :medium)

          expect(result).to be(chat)
        end

        it 'accepts symbol budgets' do
          chat = RubyLLM.chat(model: model, provider: provider)

          expect { chat.with_thinking(budget: :low) }.not_to raise_error
        end

        it 'accepts integer budgets' do
          chat = RubyLLM.chat(model: model, provider: provider)

          expect { chat.with_thinking(budget: 5000) }.not_to raise_error
        end

        it 'defaults to medium budget when not specified' do
          chat = RubyLLM.chat(model: model, provider: provider)

          expect { chat.with_thinking }.not_to raise_error
        end
      end
    end

    it 'raises UnsupportedFeatureError for models without reasoning capability' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano', provider: :openai)

      expect { chat.with_thinking(budget: :medium) }
        .to raise_error(RubyLLM::UnsupportedFeatureError, /does not support extended thinking/)
    end
  end

  describe '#thinking_enabled?' do
    THINKING_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]

      context "with #{provider}/#{model}" do
        it 'returns false by default' do
          chat = RubyLLM.chat(model: model, provider: provider)

          expect(chat.thinking_enabled?).to be false
        end

        it 'returns true after with_thinking is called' do
          chat = RubyLLM.chat(model: model, provider: provider)
          chat.with_thinking(budget: :medium)

          expect(chat.thinking_enabled?).to be true
        end
      end
    end
  end

  describe 'extended thinking integration' do
    THINKING_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]

      context "with #{provider}/#{model}" do
        it 'returns thinking content with response' do
          chat = RubyLLM.chat(model: model, provider: provider)
                        .with_thinking(budget: :low)

          response = chat.ask('What is 15 * 23? Think through this step by step.')

          expect(response.content).to be_present
          expect(response.thinking).to be_present
          expect(response.thinking.length).to be > 10
        end

        it 'returns thinking content when streaming' do
          chat = RubyLLM.chat(model: model, provider: provider)
                        .with_thinking(budget: :low)

          chunks = []
          response = chat.ask('What is 8 * 7? Show your work.') do |chunk|
            chunks << chunk
          end

          expect(response.content).to be_present
          expect(response.thinking).to be_present
          expect(chunks).not_to be_empty
        end

        it 'maintains thinking across multi-turn conversation' do
          chat = RubyLLM.chat(model: model, provider: provider)
                        .with_thinking(budget: :low)

          first_response = chat.ask('What is 5 + 3?')
          expect(first_response.thinking).to be_present

          second_response = chat.ask('Now multiply that by 2')
          expect(second_response.thinking).to be_present
          expect(second_response.content).to be_present
        end
      end
    end
  end
end

RSpec.describe RubyLLM::Providers::Anthropic::Chat do
  include_context 'with configured RubyLLM'

  describe '.resolve_budget' do
    let(:model) { RubyLLM.models.find('claude-sonnet-4-20250514') }

    it 'resolves :low to 1024 tokens' do
      expect(described_class.resolve_budget(:low, model)).to eq(1024)
    end

    it 'resolves :medium to 10,000 tokens' do
      expect(described_class.resolve_budget(:medium, model)).to eq(10_000)
    end

    it 'resolves :high to 32,000 tokens' do
      expect(described_class.resolve_budget(:high, model)).to eq(32_000)
    end

    it 'passes through integer budgets unchanged' do
      expect(described_class.resolve_budget(15_000, model)).to eq(15_000)
    end

    it 'defaults unknown symbols to 10,000' do
      expect(described_class.resolve_budget(:unknown, model)).to eq(10_000)
    end
  end
end

RSpec.describe RubyLLM::Providers::Gemini::Chat do
  include_context 'with configured RubyLLM'

  describe '.resolve_budget' do
    it 'resolves :low to 1024 tokens' do
      expect(described_class.resolve_budget(:low)).to eq(1024)
    end

    it 'resolves :medium to 8192 tokens' do
      expect(described_class.resolve_budget(:medium)).to eq(8192)
    end

    it 'resolves :high to 24,576 tokens' do
      expect(described_class.resolve_budget(:high)).to eq(24_576)
    end

    it 'passes through integer budgets unchanged' do
      expect(described_class.resolve_budget(12_000)).to eq(12_000)
    end

    it 'defaults unknown symbols to 8192' do
      expect(described_class.resolve_budget(:unknown)).to eq(8192)
    end
  end

  describe '.resolve_effort_level' do
    it 'resolves :low to "low"' do
      expect(described_class.resolve_effort_level(:low)).to eq('low')
    end

    it 'resolves :medium to "medium"' do
      expect(described_class.resolve_effort_level(:medium)).to eq('medium')
    end

    it 'resolves :high to "high"' do
      expect(described_class.resolve_effort_level(:high)).to eq('high')
    end

    it 'resolves large integers to "high"' do
      expect(described_class.resolve_effort_level(20_000)).to eq('high')
    end

    it 'resolves small integers to "low"' do
      expect(described_class.resolve_effort_level(5000)).to eq('low')
    end

    it 'defaults unknown symbols to "high"' do
      expect(described_class.resolve_effort_level(:unknown)).to eq('high')
    end
  end

  describe '.gemini_3_model?' do
    it 'detects Gemini 3 models by name' do
      model = RubyLLM::Model::Info.new(
        id: 'gemini-3-flash',
        name: 'Gemini 3 Flash',
        provider: 'gemini'
      )

      expect(described_class.gemini_3_model?(model)).to be true
    end

    it 'does not detect Gemini 2.5 as Gemini 3' do
      model = RubyLLM::Model::Info.new(
        id: 'gemini-2.5-pro',
        name: 'Gemini 2.5 Pro',
        provider: 'gemini'
      )

      expect(described_class.gemini_3_model?(model)).to be false
    end
  end
end

RSpec.describe RubyLLM::Providers::OpenAI::Chat do
  include_context 'with configured RubyLLM'

  describe '.resolve_effort' do
    it 'resolves :low to "low"' do
      expect(described_class.resolve_effort(:low)).to eq('low')
    end

    it 'resolves :medium to "high"' do
      expect(described_class.resolve_effort(:medium)).to eq('high')
    end

    it 'resolves :high to "high"' do
      expect(described_class.resolve_effort(:high)).to eq('high')
    end

    it 'resolves large integers to "high"' do
      expect(described_class.resolve_effort(15_000)).to eq('high')
    end

    it 'resolves small integers to "low"' do
      expect(described_class.resolve_effort(5000)).to eq('low')
    end

    it 'defaults unknown symbols to "high"' do
      expect(described_class.resolve_effort(:unknown)).to eq('high')
    end
  end

  describe '.grok_model?' do
    it 'detects Grok models by name' do
      model = RubyLLM::Model::Info.new(
        id: 'grok-4',
        name: 'Grok 4',
        provider: 'openai'
      )

      expect(described_class.grok_model?(model)).to be true
    end

    it 'does not detect regular OpenAI models as Grok' do
      model = RubyLLM::Model::Info.new(
        id: 'gpt-4o',
        name: 'GPT-4o',
        provider: 'openai'
      )

      expect(described_class.grok_model?(model)).to be false
    end
  end
end

RSpec.describe RubyLLM::Chunk do
  include_context 'with configured RubyLLM'

  it 'can include thinking content' do
    chunk = described_class.new(
      role: :assistant,
      content: 'Answer',
      thinking: 'Reasoning',
      model_id: 'claude-sonnet-4-20250514'
    )

    expect(chunk.thinking).to eq('Reasoning')
  end

  it 'can include thinking_signature' do
    chunk = described_class.new(
      role: :assistant,
      content: 'Answer',
      thinking: 'Reasoning',
      thinking_signature: 'sig-123',
      model_id: 'claude-sonnet-4-20250514'
    )

    expect(RubyLLM::Messages.signature_for(chunk)).to eq('sig-123')
  end
end

RSpec.describe RubyLLM::UnsupportedFeatureError do
  include_context 'with configured RubyLLM'

  it 'is a subclass of RubyLLM::Error' do
    expect(described_class).to be < RubyLLM::Error
  end

  it 'can be raised with a custom message' do
    expect { raise described_class, 'Feature not supported' }
      .to raise_error(described_class, 'Feature not supported')
  end

  it 'does not require a response object' do
    error = described_class.new('Test error')

    expect(error.response).to be_nil
    expect(error.message).to eq('Test error')
  end
end
# rubocop:enable RSpec/MultipleDescribes
