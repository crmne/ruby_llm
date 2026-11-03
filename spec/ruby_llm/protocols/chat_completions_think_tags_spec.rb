# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions do
  let(:config) { RubyLLM::Configuration.new }
  let(:protocol) do
    described_class.allocate.tap { |protocol| protocol.instance_variable_set(:@config, config) }
  end
  let(:samples) do
    ["<think>reasoning</think>\nanswer", '<think>unclosed', " \n<think>a</think>b", 'plain <think>x</think>',
     '<think', '<THINK>x</THINK>', '', '   ', "\xFF<think>".dup.force_encoding('UTF-8')]
  end

  def complete(content, **message)
    message = { 'role' => 'assistant', 'content' => content, **message }
    body = { 'model' => 'qwen3', 'choices' => [{ 'message' => message }] }
    protocol.send(:parse_completion_body, body, raw: instance_double(Faraday::Response, body: body))
  end

  def stream(*deltas)
    chunks = []
    allow(protocol).to receive(:stream_events) do |*, &block|
      deltas.each { |delta| block.call('model' => 'qwen3', 'choices' => [{ 'delta' => delta }]) }
      instance_double(Faraday::Response)
    end
    message = protocol.send(:stream_response, {}) { |chunk| chunks << chunk }
    [message, chunks]
  end

  def contents(*pieces)
    pieces.map { |piece| { 'content' => piece } }
  end

  context 'with split_think_tags off' do
    it 'leaves every completion as the provider sent it' do
      allow(described_class::ThinkTags).to receive(:split)

      samples.each do |sample|
        message = complete(sample)

        expect(message.content).to eq(sample)
        expect(message.thinking).to be_nil
      end
      expect(described_class::ThinkTags).not_to have_received(:split)
    end

    it 'leaves every streamed chunk as the provider sent it' do
      allow(described_class::ThinkTags).to receive(:new)

      samples.reject(&:empty?).each do |sample|
        pieces = sample.chars
        message, chunks = stream(*contents(*pieces))

        expect(chunks.map(&:content)).to eq(pieces)
        expect(chunks.map(&:thinking)).to all(be_nil)
        expect(message.content).to eq(sample)
        expect(message.thinking).to be_nil
      end
      expect(described_class::ThinkTags).not_to have_received(:new)
    end
  end

  context 'with split_think_tags on' do
    before { config.split_think_tags = true }

    it 'splits a completion' do
      message = complete("<think>reasoning</think>\nanswer")

      expect(message.content).to eq('answer')
      expect(message.thinking.text).to eq('reasoning')
    end

    it 'treats an unclosed completion block as thinking' do
      message = complete('<think>cut off')

      expect(message.content).to be_nil
      expect(message.thinking.text).to eq('cut off')
    end

    it 'prefers reasoning_content to tags in a completion' do
      message = complete('<think>inline</think>answer', 'reasoning_content' => 'native')

      expect(message.content).to eq('<think>inline</think>answer')
      expect(message.thinking.text).to eq('native')
    end

    it 'splits a stream with tags cut across chunks, and its chunks agree with the message' do
      message, chunks = stream(*contents('<thi', 'nk>reason', 'ing</th', "ink>\nans", 'wer'))

      expect(message.content).to eq('answer')
      expect(message.thinking.text).to eq('reasoning')
      expect(chunks.filter_map(&:content).join).to eq('answer')
      expect(chunks.filter_map { |chunk| chunk.thinking&.text }.join).to eq('reasoning')
    end

    it 'streams an unclosed block as thinking, including a held partial closing tag' do
      message, chunks = stream(*contents('<think>cut off </thi'))

      expect(message.content).to be_nil
      expect(message.thinking.text).to eq('cut off </thi')
      expect(chunks.filter_map { |chunk| chunk.thinking&.text }.join).to eq('cut off </thi')
    end

    it 'delivers a held partial opening tag as content when the stream ends' do
      message, chunks = stream(*contents('<thi'))

      expect(message.content).to eq('<thi')
      expect(chunks.filter_map(&:content).join).to eq('<thi')
    end

    it 'prefers streamed reasoning_content to tags' do
      message, = stream({ 'reasoning_content' => 'native' }, *contents('<think>', 'inline</think>answer'))

      expect(message.content).to eq('<think>inline</think>answer')
      expect(message.thinking.text).to eq('native')
    end

    it 'splits every chunk of a one-byte stream the same way as the whole completion' do
      text = "<think>#{'step ' * 200}</think>\n#{'answer ' * 200}"
      message, chunks = stream(*contents(*text.chars))
      whole = complete(text)

      expect(message.content).to eq(whole.content)
      expect(message.thinking.text).to eq(whole.thinking.text)
      expect(chunks.filter_map(&:content).join).to eq(whole.content)
    end

    it 'reads the setting from a context' do
      context = RubyLLM.context do |context_config|
        context_config.ollama_api_base = 'http://localhost:11434/v1'
        context_config.split_think_tags = true
      end
      provider = RubyLLM::Providers::Ollama.new(context.config)
      contextual = described_class.new(provider, nil)
      body = { 'model' => 'qwen3', 'choices' => [{ 'message' => { 'content' => '<think>r</think>a' } }] }

      message = contextual.send(:parse_completion_body, body, raw: nil)

      expect([message.content, message.thinking.text]).to eq(%w[a r])
      expect(RubyLLM.config.split_think_tags).to be(false)
    end
  end
end
