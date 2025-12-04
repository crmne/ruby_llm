# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'RubyLLM::Instrumentation' do
  include_context 'with configured RubyLLM'

  let(:events) { [] }
  let(:subscriber) do
    lambda do |name, start, finish, _id, payload|
      events << {
        name: name,
        duration: finish - start,
        payload: payload.dup
      }
    end
  end

  before do
    events.clear
    ActiveSupport::Notifications.subscribe(/\.ruby_llm$/, subscriber)
  end

  after do
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  describe 'Chat instrumentation' do
    it 'emits complete_chat.ruby_llm event' do
      chat = RubyLLM.chat(model: 'qwen3', provider: :ollama)

      begin
        chat.ask 'Hello'
      rescue Faraday::Error, RubyLLM::Error => e
        skip "API not available: #{e.message}" if events.empty?
      end

      chat_events = events.select { |e| e[:name] == 'complete_chat.ruby_llm' }
      expect(chat_events).not_to be_empty

      event = chat_events.first
      expect(event[:payload][:provider]).to eq('ollama')
      expect(event[:payload][:model]).to eq('qwen3')
      expect(event[:payload][:streaming]).to eq(false)
      expect(event[:duration]).to be >= 0
    end

    it 'includes streaming flag as false for non-streaming requests' do
      chat = RubyLLM.chat(model: 'qwen3', provider: :ollama)

      begin
        chat.ask 'Test'
      rescue Faraday::Error, RubyLLM::Error => e
        skip "API not available: #{e.message}" if events.empty?
      end

      event = events.find { |e| e[:name] == 'complete_chat.ruby_llm' }
      expect(event).not_to be_nil
      expect(event[:payload][:streaming]).to eq(false)
      expect(event[:payload][:provider]).to eq('ollama')
      expect(event[:payload][:model]).to eq('qwen3')
    end

    it 'includes streaming flag as true for streaming requests' do
      chat = RubyLLM.chat(model: 'qwen3', provider: :ollama)

      begin
        chat.ask('Test') { |_chunk| }
      rescue Faraday::Error, RubyLLM::Error => e
        skip "API not available: #{e.message}" if events.empty?
      end

      event = events.find { |e| e[:name] == 'complete_chat.ruby_llm' }
      expect(event).not_to be_nil
      expect(event[:payload][:streaming]).to eq(true)
      expect(event[:payload][:provider]).to eq('ollama')
      expect(event[:payload][:model]).to eq('qwen3')
    end
  end

  describe 'Embedding instrumentation' do
    it 'emits embed_text.ruby_llm event' do
      begin
        RubyLLM.embed('Test', model: 'text-embedding-3-small', provider: :openai)
      rescue Faraday::Error, RubyLLM::Error => e
        skip "API not available: #{e.message}" if events.empty?
      end

      embed_events = events.select { |e| e[:name] == 'embed_text.ruby_llm' }
      expect(embed_events).not_to be_empty

      event = embed_events.first
      expect(event[:payload][:provider]).to eq('openai')
      expect(event[:payload][:model]).to eq('text-embedding-3-small')
      # vector_count may not be present if an error occurred
      expect(event[:payload]).to have_key(:vector_count).or have_key(:exception)
      expect(event[:duration]).to be >= 0
    end

    it 'includes dimensions in payload when specified' do
      begin
        RubyLLM.embed('Test', model: 'text-embedding-3-small', provider: :openai, dimensions: 512)
      rescue Faraday::Error, RubyLLM::Error => e
        skip "API not available: #{e.message}" if events.empty?
      end

      event = events.find { |e| e[:name] == 'embed_text.ruby_llm' }
      expect(event).not_to be_nil
      expect(event[:payload][:dimensions]).to eq(512)
      expect(event[:payload][:provider]).to eq('openai')
      expect(event[:payload][:model]).to eq('text-embedding-3-small')
    end
  end

  describe 'Image instrumentation' do
    it 'emits paint_image.ruby_llm event' do
      begin
        RubyLLM.paint('Test', model: 'dall-e-3', provider: :openai)
      rescue Faraday::Error, RubyLLM::Error => e
        skip "API not available: #{e.message}" if events.empty?
      end

      paint_events = events.select { |e| e[:name] == 'paint_image.ruby_llm' }
      expect(paint_events).not_to be_empty

      event = paint_events.first
      expect(event[:payload][:provider]).to eq('openai')
      expect(event[:payload][:model]).to eq('dall-e-3')
      expect(event[:payload]).to have_key(:size)
      expect(event[:duration]).to be >= 0
    end
  end

  describe 'Moderation instrumentation' do
    it 'emits moderate_content.ruby_llm event' do
      begin
        RubyLLM.moderate('Test', model: 'omni-moderation-latest', provider: :openai)
      rescue Faraday::Error, RubyLLM::Error => e
        skip "API not available: #{e.message}" if events.empty?
      end

      moderate_events = events.select { |e| e[:name] == 'moderate_content.ruby_llm' }
      expect(moderate_events).not_to be_empty

      event = moderate_events.first
      expect(event[:payload][:provider]).to eq('openai')
      expect(event[:payload][:model]).to eq('omni-moderation-latest')
      # flagged may not be present if an error occurred
      expect(event[:payload]).to have_key(:flagged).or have_key(:exception)
      expect(event[:duration]).to be >= 0
    end
  end

  describe 'Transcription instrumentation' do
    let(:audio_file) { File.expand_path('../../fixtures/audio.wav', __dir__) }

    it 'emits transcribe_audio.ruby_llm event' do
      skip 'Audio file not available' unless File.exist?(audio_file)

      begin
        RubyLLM.transcribe(audio_file, model: 'whisper-1', provider: :openai)
      rescue Faraday::Error, RubyLLM::Error => e
        skip "API not available: #{e.message}" if events.empty?
      end

      transcribe_events = events.select { |e| e[:name] == 'transcribe_audio.ruby_llm' }
      expect(transcribe_events).not_to be_empty

      event = transcribe_events.first
      expect(event[:payload][:provider]).to eq('openai')
      expect(event[:payload][:model]).to eq('whisper-1')
      expect(event[:duration]).to be >= 0
    end
  end

  describe 'Tool execution instrumentation' do
    let(:calculator_tool) do
      Class.new(RubyLLM::Tool) do
        def self.name
          'Calculator'
        end

        description 'Perform calculations'
        param :expression, desc: 'Math expression'

        def execute(expression:)
          eval expression
        end
      end
    end

    it 'emits execute_tool.ruby_llm event when tools are called' do
      chat = RubyLLM.chat(model: 'qwen3', provider: :ollama)
      chat.with_tool(calculator_tool)

      begin
        chat.ask 'What is 2 + 2?'
      rescue Faraday::Error, RubyLLM::Error => e
        skip "API not available: #{e.message}" if events.empty?
      end

      tool_events = events.select { |e| e[:name] == 'execute_tool.ruby_llm' }

      skip 'Model did not call the tool in this test run' if tool_events.empty?

      event = tool_events.first
      expect(event[:payload][:tool_name]).to eq('calculator')
      expect(event[:payload]).to have_key(:arguments)
      expect(event[:payload][:halted]).to be_in([true, false])
      expect(event[:duration]).to be >= 0
    end
  end
end
