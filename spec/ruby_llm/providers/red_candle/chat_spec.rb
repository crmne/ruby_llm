# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::RedCandle::Chat do
  let(:config) { RubyLLM::Configuration.new }
  let(:provider) { RubyLLM::Providers::RedCandle.new(config) }
  let(:model) { provider.model('TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF') }

  before(:all) do
    begin
      require 'candle'
    rescue LoadError
      skip 'Red Candle gem is not installed'
    end
  end

  describe '#render_payload' do
    let(:messages) { [{ role: 'user', content: 'Hello' }] }

    it 'creates a valid payload' do
      payload = provider.render_payload(
        messages,
        tools: nil,
        temperature: 0.7,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload).to include(
        messages: messages,
        temperature: 0.7,
        model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
        stream: false,
        schema: nil
      )
    end

    it 'raises error when tools are provided' do
      tools = [{ name: 'calculator', description: 'Does math' }]

      expect do
        provider.render_payload(
          messages,
          tools: tools,
          temperature: 0.7,
          model: model,
          stream: false,
          schema: nil
        )
      end.to raise_error(RubyLLM::Error, /does not support tool calling/)
    end

    it 'includes schema when provided' do
      schema = { type: 'object', properties: { name: { type: 'string' } } }

      payload = provider.render_payload(
        messages,
        tools: nil,
        temperature: 0.7,
        model: model,
        stream: false,
        schema: schema
      )

      expect(payload[:schema]).to eq(schema)
    end
  end

  describe '#perform_completion!' do
    let(:messages) { [{ role: 'user', content: 'Test message' }] }
    let(:mock_model) { double('Candle::LLM') }

    before do
      allow(provider).to receive(:ensure_model_loaded!).and_return(mock_model)
      allow(mock_model).to receive(:respond_to?).with(:apply_chat_template).and_return(true)
      allow(mock_model).to receive(:apply_chat_template).and_return('formatted prompt')
    end

    context 'with regular generation' do
      it 'generates a response' do
        allow(mock_model).to receive(:generate).and_return('Generated response')

        payload = {
          messages: messages,
          model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
          temperature: 0.7
        }

        result = provider.perform_completion!(payload)

        expect(result).to include(
          content: 'Generated response',
          role: 'assistant'
        )
      end
    end

    context 'with structured generation' do
      it 'generates structured output' do
        schema = { type: 'object', properties: { name: { type: 'string' } } }
        structured_response = { 'name' => 'Alice' }

        allow(mock_model).to receive(:generate_structured).and_return(structured_response)

        payload = {
          messages: messages,
          model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
          temperature: 0.7,
          schema: schema
        }

        result = provider.perform_completion!(payload)

        expect(result[:content]).to eq(JSON.generate(structured_response))
        expect(result[:role]).to eq('assistant')
      end

      it 'falls back to regular generation on structured failure' do
        schema = { type: 'object', properties: { name: { type: 'string' } } }

        allow(mock_model).to receive(:generate_structured).and_raise(StandardError, 'Structured gen failed')
        allow(mock_model).to receive(:generate).and_return('Fallback response')
        allow(RubyLLM.logger).to receive(:warn)

        payload = {
          messages: messages,
          model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
          temperature: 0.7,
          schema: schema
        }

        result = provider.perform_completion!(payload)

        expect(result[:content]).to eq('Fallback response')
        expect(RubyLLM.logger).to have_received(:warn).with(/Structured generation failed/)
      end
    end
  end

  describe '#perform_streaming_completion!' do
    let(:messages) { [{ role: 'user', content: 'Stream test' }] }
    let(:mock_model) { double('Candle::LLM') }

    before do
      allow(provider).to receive(:ensure_model_loaded!).and_return(mock_model)
      allow(mock_model).to receive(:respond_to?).with(:apply_chat_template).and_return(true)
      allow(mock_model).to receive(:apply_chat_template).and_return('formatted prompt')
    end

    it 'streams tokens and sends finish reason' do
      tokens = %w[Hello world !]
      chunks_received = []

      allow(mock_model).to receive(:generate_stream) do |_prompt, config:, &block|
        tokens.each { |token| block.call(token) }
      end

      payload = {
        messages: messages,
        model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
        temperature: 0.7
      }

      provider.perform_streaming_completion!(payload) do |chunk|
        chunks_received << chunk
      end

      # Check token chunks
      tokens.each_with_index do |token, i|
        chunk = chunks_received[i]
        expect(chunk).to be_a(RubyLLM::Chunk)
        expect(chunk.content).to eq(token)
      end

      # Check final chunk (empty content indicates completion)
      final_chunk = chunks_received.last
      expect(final_chunk).to be_a(RubyLLM::Chunk)
      expect(final_chunk.content).to eq('')
    end
  end

  describe 'message formatting' do
    it 'handles string content' do
      messages = [{ role: 'user', content: 'Simple text' }]
      formatted = provider.send(:format_messages, messages)

      expect(formatted).to eq([{ role: 'user', content: 'Simple text' }])
    end

    it 'handles array content with text parts' do
      messages = [{
        role: 'user',
        content: [
          { type: 'text', text: 'Part 1' },
          { type: 'text', text: 'Part 2' },
          { type: 'image', url: 'ignored.jpg' }
        ]
      }]

      formatted = provider.send(:format_messages, messages)
      expect(formatted).to eq([{ role: 'user', content: 'Part 1 Part 2' }])
    end
  end
end