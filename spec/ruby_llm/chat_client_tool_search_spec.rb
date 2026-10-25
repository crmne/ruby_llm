# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  before do
    stub_const('CurrentTime', Class.new(RubyLLM::Tool) do
      description 'Returns the current time'
      def execute = '12:00'
    end)
    stub_const('WeatherLookup', Class.new(RubyLLM::Tool) do
      description 'Looks up the current weather for a city'
      parameter :city, description: 'City name'
      def execute(city:) = "Sunny in #{city}"
    end)
    stub_const('StockPrice', Class.new(RubyLLM::Tool) do
      description 'Looks up the current price of a stock ticker'
      parameter :ticker, description: 'Ticker symbol'
      def execute(ticker:) = "#{ticker} is at 100"
    end)
    stub_const('NewsSearch', Class.new(RubyLLM::Tool) do
      description 'Searches recent news articles'
      parameter :topic, description: 'What the news is about'
      def execute(topic:) = "No news about #{topic}"
    end)
  end

  let(:chat) do
    RubyLLM.chat(model: model_for(:gemini), provider: :gemini)
           .with_tools(CurrentTime)
           .with_tools(WeatherLookup, StockPrice, NewsSearch, defer: true)
  end

  def declared(chat)
    chat.render[:tools].flat_map { |tool| tool[:functionDeclarations] }.map { |declaration| declaration[:name] }
  end

  def searched(chat, query, id: 'search_1')
    call = RubyLLM::ToolCall.new(id:, name: 'tool_search', arguments: { 'query' => query })
    chat.add_message(role: :assistant, content: nil, tool_calls: { id => call })
    chat.add_message(role: :tool, content: chat.tools[:tool_search].call(query:).to_json, tool_call_id: id)
  end

  describe 'on a provider without tool search' do
    it 'offers the tools that are not deferred and a tool_search tool' do
      chat.add_message(role: :user, content: 'Hi')

      expect(declared(chat)).to eq(%w[current_time tool_search])
    end

    it 'lists the deferred tools in the search tool' do
      expect(chat.tools[:tool_search].description)
        .to include('weather_lookup, stock_price, news_search')
    end

    it 'loads the tools a search found for the next requests, after the others' do
      chat.add_message(role: :user, content: 'What is the weather in Berlin?')
      searched(chat, 'weather city')

      expect(declared(chat)).to eq(%w[current_time tool_search weather_lookup])
    end

    it 'appends tools loaded later in the order they were loaded' do
      chat.add_message(role: :user, content: 'Stocks, then weather')
      searched(chat, 'stock price')
      searched(chat, 'weather', id: 'search_2')

      expect(declared(chat)).to eq(%w[current_time tool_search stock_price weather_lookup])
    end

    it 'keeps offering a deferred tool the conversation called' do
      call = RubyLLM::ToolCall.new(id: 'call_1', name: 'news_search', arguments: { 'topic' => 'Ruby' })
      chat.add_message(role: :user, content: 'News?')
      chat.add_message(role: :assistant, content: nil, tool_calls: { 'call_1' => call })
      chat.add_message(role: :tool, content: 'No news', tool_call_id: 'call_1')

      expect(declared(chat)).to eq(%w[current_time tool_search news_search])
    end

    it 'loads tools by name with select:, in the order named' do
      result = chat.tools[:tool_search].call(query: 'select:news_search, stock_price, missing')

      expect(result[:loaded]).to eq(%w[news_search stock_price])
    end

    it 'says which tools there are when nothing matches' do
      result = chat.tools[:tool_search].call(query: 'calendar')

      expect(result[:loaded]).to eq([])
      expect(result[:error]).to include('weather_lookup, stock_price, news_search')
    end

    it 'loads nothing for a search result it cannot read' do
      call = RubyLLM::ToolCall.new(id: 'search_1', name: 'tool_search', arguments: { 'query' => 'x' })
      chat.add_message(role: :user, content: 'Hi')
      chat.add_message(role: :assistant, content: nil, tool_calls: { 'search_1' => call })
      chat.add_message(role: :tool, content: 'not json', tool_call_id: 'search_1')

      expect(declared(chat)).to eq(%w[current_time tool_search])
    end

    it "searches a copy's own deferred tools" do
      bond_price = Class.new(StockPrice) { def self.tool_name = 'bond_price' }
      chat.tools
      copy = chat.dup.with_tools(bond_price.new.defer)

      expect(copy.tools[:tool_search].description).to include('bond_price')
      expect(chat.tools[:tool_search].description).not_to include('bond_price')
    end

    it 'loads a deferred namespaced tool by its joined name' do
      lookup = Class.new(RubyLLM::Tool) do
        namespace 'crm'
        description 'Finds a customer by email'
        def self.tool_name = 'customer_lookup'
        def execute = 'Ada'
      end
      chat.with_tools(lookup, defer: true)
      chat.add_message(role: :user, content: 'Find Ada')
      searched(chat, 'customer')

      expect(declared(chat)).to eq(%w[current_time tool_search crm_customer_lookup])
    end

    it 'offers no search tool when nothing is deferred' do
      plain = RubyLLM.chat(model: model_for(:gemini), provider: :gemini).with_tools(CurrentTime)

      expect(plain.tools.keys).to eq(%i[current_time])
    end
  end

  describe 'on a provider with tool search' do
    it 'leaves the search to the provider' do
      native = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)
                      .with_tools(WeatherLookup, defer: true)

      expect(native.tools.keys).to eq(%i[weather_lookup])
      expect(native.render[:tools].map { |tool| tool[:name] }).to include('weather_lookup', 'tool_search_tool_bm25')
    end
  end

  it 'defers one instance of a tool class' do
    chat = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)

    chat.with_tools(WeatherLookup.new.defer, StockPrice.new)

    expect(chat.deferred_tools.keys).to eq(%i[weather_lookup])
    expect(WeatherLookup.new).not_to be_deferred
  end

  describe RubyLLM::Tools::Search do
    def tool(name, description)
      Class.new(RubyLLM::Tool) do
        description description
        parameter :query, description: 'What to look for'
        define_method(:name) { name }
        def execute(query:) = query
      end.new
    end

    let(:tools) do
      [tool('newsletter_send', 'Sends a mailing'), tool('news_search', 'Finds articles'),
       tool('clip_save', 'Saves a clip from the news'), tool('stock_price', 'Looks up a ticker')]
        .to_h { |found| [found.name.to_sym, found] }
    end
    let(:search) { described_class.new(-> { tools }) }

    it 'loads no more than the limit by name either' do
      expect(search.call(query: 'select:news_search,clip_save,stock_price', limit: 2)[:loaded])
        .to eq(%w[news_search clip_save])
    end

    it 'ranks a word of the name over part of it, and that over the description' do
      expect(search.call(query: 'news')[:loaded]).to eq(%w[news_search newsletter_send clip_save])
    end

    it 'matches parameter names' do
      expect(search.call(query: 'query', limit: 1)[:loaded]).to eq(%w[newsletter_send])
    end

    it 'loads at most the limit, between 1 and 20' do
      expect(search.call(query: 'news', limit: 0)[:loaded].size).to eq(1)
      expect(search.call(query: 'query', limit: 50)[:loaded].size).to eq(4)
    end

    it 'finds and loads namespaced tools by their qualified names' do
      tools[:crm_news_search] = tool('news_search', 'Finds customer notes')

      expect(search.call(query: 'crm')[:loaded]).to eq(%w[crm_news_search])
      expect(search.call(query: 'select:crm_news_search')[:tools]).to eq(
        [{ name: 'crm_news_search', description: 'Finds customer notes' }]
      )
    end

    it 'takes only a query and a limit' do
      expect(search.parameters_schema).to include('required' => %w[query], 'additionalProperties' => false)
    end

    it 'shortens long descriptions in its result' do
      tools[:news_search] = tool('news_search', "#{'a' * 199}b")
      tools[:clip_save] = tool('clip_save', 'c' * 201)

      described = search.call(query: 'select:news_search,clip_save')[:tools].to_h do |found|
        [found[:name], found[:description]]
      end

      expect(described['news_search']).to eq("#{'a' * 199}b")
      expect(described['clip_save']).to eq("#{'c' * 197}...")
    end
  end
end
