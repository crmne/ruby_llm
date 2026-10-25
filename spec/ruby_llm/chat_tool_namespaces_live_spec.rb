# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  include_context 'with configured RubyLLM'

  let(:requests) { [] }

  before do
    stub_const('Screenshot', Class.new(RubyLLM::Tool) do
      namespace 'computer'
      description 'Captures the screen'

      def self.tool_name = 'screenshot'

      def execute = RubyLLM::Attachment.new(File.expand_path('../fixtures/ruby.png', __dir__))
    end)
    stub_const('LeftClick', Class.new(RubyLLM::Tool) do
      namespace 'computer'

      def self.tool_name = 'left_click'

      def execute(**) = { error: 'The display is locked' }
    end)
    stub_const('CustomerLookup', Class.new(RubyLLM::Tool) do
      namespace 'crm', description: 'Customer records'
      description 'Finds a customer by email'
      parameter :email, description: 'Customer email'

      def execute(email:) = { email:, name: 'Ada Lovelace', plan: 'Pro' }
    end)
  end

  def record_requests(chat)
    chat.before_request { |payload| requests << JSON.parse(JSON.generate(payload)) }
  end

  def results_in(request)
    request['messages'].flat_map { |message| Array(message['content']) }
                       .select { |block| block.is_a?(Hash) && block['type'] == 'tool_result' }
  end

  describe 'Anthropic computer toolset' do
    let(:model) { model_for(:anthropic, :client_toolset) }
    let(:chat) do
      RubyLLM.chat(model:, provider: :anthropic)
             .with_provider_tools({ type: 'computer_toolset_20260801' })
    end

    it 'returns a screenshot to a computer member call' do
      record_requests(chat.with_tools(Screenshot))

      response = chat.ask('Take a screenshot and tell me in a few words what is on the screen.')

      call = chat.messages.find(&:tool_call?).tool_calls.values.first
      expect(call).to have_attributes(name: 'screenshot', namespace: 'computer')
      result = results_in(requests.last).first
      expect(result).to include('toolset_name' => 'computer')
      expect(result['content'].map { |block| block['type'] }).to include('image')
      expect(response.content).to be_present
    end

    it 'answers the rest of an ordered batch as not executed after a failure' do
      record_requests(chat.with_tools(LeftClick, Screenshot))

      chat.ask('In one turn, without waiting for results, call left_click at [10, 10] and then screenshot.')

      results = requests.flat_map { |request| results_in(request) }.uniq { |result| result['tool_use_id'] }
      calls = chat.messages.select(&:tool_call?).flat_map { |message| message.tool_calls.values }
      expect(calls.map(&:name).first(2)).to eq(%w[left_click screenshot])
      expect(results.first(2)).to all(include('is_error' => true, 'toolset_name' => 'computer'))
      expect(results[1]['content']).to eq(
        [{ 'type' => 'text', 'text' => 'Not executed: an earlier computer action in this turn failed.' }]
      )
      expect(chat.messages.last.content).to be_present
    end
  end

  describe 'Anthropic namespaced functions' do
    let(:model) { model_for(:anthropic, :client_toolset) }
    let(:chat) { RubyLLM.chat(model:, provider: :anthropic) }

    it 'calls a namespaced function by its joined name' do
      record_requests(chat.with_tools(CustomerLookup))

      response = chat.ask('Which plan is the customer ada@example.com on? Use your tools.')

      call = chat.messages.find(&:tool_call?).tool_calls.values.first
      expect(call).to have_attributes(name: 'customer_lookup', namespace: 'crm')
      expect(requests.first['tools'].map { |tool| tool['name'] }).to eq(['crm_customer_lookup'])
      expect(response.content).to include('Pro')
    end
  end

  describe 'Chat Completions namespaced functions' do
    let(:chat) do
      RubyLLM.chat(model: model_for(:openai, :tool_namespace), provider: :openai, protocol: :chat_completions)
    end

    it 'calls a namespaced function by its joined name' do
      response = chat.with_tools(CustomerLookup).ask('Which plan is the customer ada@example.com on? Use your tools.')

      call = chat.messages.find(&:tool_call?).tool_calls.values.first
      expect(call).to have_attributes(name: 'customer_lookup', namespace: 'crm')
      expect(response.content).to include('Pro')
    end
  end

  describe 'Responses namespaces' do
    let(:model) { model_for(:openai, :tool_namespace) }
    let(:chat) { RubyLLM.chat(model:, provider: :openai, protocol: :responses) }

    it 'calls a namespaced function and replays its namespace' do
      record_requests(chat.with_tools(CustomerLookup))

      response = chat.ask('Which plan is the customer ada@example.com on? Use your tools.')

      call = chat.messages.find(&:tool_call?).tool_calls.values.first
      expect(call).to have_attributes(name: 'customer_lookup', namespace: 'crm')
      expect(requests.first['tools']).to include(include('type' => 'namespace', 'name' => 'crm',
                                                         'description' => 'Customer records'))
      replayed = requests.last['input'].find { |item| item['type'] == 'function_call' }
      expect(replayed).to include('namespace' => 'crm', 'name' => 'customer_lookup')
      expect(response.content).to include('Pro')
    end

    it 'finds a deferred namespaced function through tool search' do
      chat.with_tools(CustomerLookup, defer: true)

      response = chat.ask('Which plan is the customer ada@example.com on? Use your tools.')

      call = chat.messages.select(&:tool_call?).flat_map { |message| message.tool_calls.values }.last
      items = chat.messages.flat_map { |message| Array(message.raw_content) }.map { |item| item['type'] }
      expect(items).to include('tool_search_output')
      expect(call).to have_attributes(name: 'customer_lookup', namespace: 'crm')
      expect(response.content).to include('Pro')
    end
  end
end
