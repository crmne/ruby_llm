# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  def define_tool_classes!
    stub_const('WeatherLookupTool', Class.new(RubyLLM::Tool) do
      description 'Looks up the current weather (temperature, wind) for a city by name.'
      deferred
      param :city, desc: 'City name, e.g. "Berlin"'
      def execute(city:) = "Weather in #{city}: 15C, wind 10 km/h, clear skies"
    end)
    stub_const('StockPriceTool', Class.new(RubyLLM::Tool) do
      description 'Fetches the latest equity stock price in USD for a ticker symbol.'
      deferred
      param :ticker, desc: 'Uppercase ticker symbol, e.g. "AAPL"'
      def execute(ticker:) = "Last trade for #{ticker}: $123.45 USD"
    end)
    stub_const('TranslateTextTool', Class.new(RubyLLM::Tool) do
      description 'Translates a short piece of text from one natural language to another.'
      deferred
      param :text, desc: 'Text to translate'
      param :target_language, desc: 'Target language name, e.g. "Spanish"'
      def execute(text:, target_language:) = "(#{target_language}) #{text.reverse}"
    end)
    stub_const('CalculatorTool', Class.new(RubyLLM::Tool) do
      description 'Evaluates a basic arithmetic expression involving +, -, *, /.'
      deferred
      param :expression, desc: 'Arithmetic expression, e.g. "2 + 2"'
      def execute(expression:) = "Result of #{expression} is 42"
    end)
    stub_const('DictionaryTool', Class.new(RubyLLM::Tool) do
      description 'Looks up the dictionary definition of an English word.'
      deferred
      param :word, desc: 'The word to define'
      def execute(word:) = "Definition of #{word}: a placeholder entry used for testing."
    end)
    stub_const('CurrentTimeTool', Class.new(RubyLLM::Tool) do
      description 'Returns the current server time as an ISO-8601 string.'
      def execute = '2026-04-24T12:00:00Z'
    end)
  end

  def deferred_tool_classes
    [WeatherLookupTool, StockPriceTool, TranslateTextTool, CalculatorTool, DictionaryTool]
  end

  def register_catalog(chat)
    chat.with_tools(*deferred_tool_classes).with_tool(CurrentTimeTool)
  end

  def request_body_for(message)
    JSON.parse(message.raw.env.request_body)
  end

  before { define_tool_classes! }

  describe 'end-to-end tool search with Anthropic' do
    let(:model) { 'claude-haiku-4-5' }
    let(:provider) { :anthropic }

    it 'promotes a deferred tool via the native tool-search primitive and answers from its output' do
      chat = RubyLLM.chat(model: model, provider: provider)
      register_catalog(chat)

      search_events = []
      chat.on_tool_search { |event| search_events << event }

      response = chat.ask("What's the current weather in Berlin? Please use your tools to look it up.")

      # Anthropic's server-side primitive surfaces loaded tools on the
      # assistant message as tool_references — our parser exposes them so
      # Chat can promote the tool into @tools for the next turn.
      assistant_messages = chat.messages.select { |m| m.role == :assistant }
      native_refs = assistant_messages.flat_map { |m| Array(m.tool_references) }
      expect(native_refs).to include('weather_lookup')

      expect(chat.tool_catalog.loaded_tools).to include(:weather_lookup)
      # Robust against paraphrase: fixture temperature is "15C"; the model
      # often rewrites as "15°C", "15 C", or "15 degrees Celsius".
      expect(response.content).to match(/15\s*(°|degrees?)?\s*C/i)
      expect(response.content).to include('10 km/h')

      # No-retry-storm guard: a working feature converges in a handful of
      # roundtrips. Not a strict contract — the model may take an extra turn.
      request_count = chat.messages.count { |m| m.role == :assistant }
      expect(request_count).to be <= 5

      # Native path fires on_tool_search with query: nil.
      expect(search_events).not_to be_empty
      expect(search_events.first.query).to be_nil
      expect(search_events.flat_map(&:results)).to include(:weather_lookup)
    end

    it 'sends defer_loading: true and the native tool_search_tool_bm25 entry on the first request' do
      chat = RubyLLM.chat(model: model, provider: provider)
      register_catalog(chat)

      chat.ask("What's the current weather in Berlin?")

      first_assistant = chat.messages.find { |m| m.role == :assistant }
      tool_entries = request_body_for(first_assistant).fetch('tools')

      deferred_entries = tool_entries.select { |t| t['defer_loading'] == true }
      expect(deferred_entries.map { |t| t['name'] }).to include(
        'weather_lookup', 'stock_price', 'translate_text', 'calculator', 'dictionary'
      )

      current_time = tool_entries.find { |t| t['name'] == 'current_time' }
      expect(current_time).not_to be_nil
      expect(current_time).not_to have_key('defer_loading')

      native = tool_entries.find { |t| t['type'] == 'tool_search_tool_bm25_20251119' }
      expect(native).not_to be_nil
      expect(native['name']).to eq('tool_search_tool_bm25')

      # Every deferred tool is visible by name and marked with defer_loading
      # for Anthropic's server-side handling.
      expect(tool_entries.map { |t| t['name'] }).not_to include('search_tools')
    end
  end
end
