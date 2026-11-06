# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { described_class.new(model: model_for(:anthropic)) }
  let(:tenant_key) { :ruby_llm_spec_tenant }

  def reader_tool(name, key)
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { name }
      define_method(:execute) { Fiber[key].to_s }
    end
  end

  def calls(*names)
    tool_calls = names.each_with_index.to_h do |name, index|
      ["call_#{index}", RubyLLM::ToolCall.new(id: "call_#{index}", name:, arguments: {})]
    end
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:)
  end

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'done', input_tokens: 1, output_tokens: 1)
  end

  def results
    chat.messages.select(&:tool_result?).map(&:content)
  end

  def with_fiber_value(key, value)
    previous = Fiber[key]
    Fiber[key] = value
    yield
  ensure
    Fiber[key] = previous
  end

  [nil, :threads, :fibers].each do |mode|
    context "with #{mode || 'sequential'} tool calls" do
      before do
        chat.with_tools(reader_tool('first', tenant_key), reader_tool('second', tenant_key))
            .with_tool_options(concurrency: mode)
        allow(chat.provider).to receive(:complete).and_return(calls('first', 'second'), answer)
      end

      it 'runs each tool inside the block, where state it sets reaches the tool' do
        key = tenant_key
        chat.around_tool_call { |call, &run| with_fiber_value(key, "acme:#{call.name}", &run) }

        chat.ask('Go')

        expect(results).to match_array(%w[acme:first acme:second])
      end

      it 'runs the block in the fiber that runs the tool' do
        fibers = Queue.new
        fiber_tool = Class.new(RubyLLM::Tool) do
          define_singleton_method(:tool_name) { 'fiber' }
          define_method(:execute) { Fiber.current.object_id.to_s }
        end
        chat = described_class.new(model: model_for(:anthropic)).with_tools(fiber_tool)
                              .with_tool_options(concurrency: mode)
        allow(chat.provider).to receive(:complete).and_return(calls('fiber', 'fiber'), answer)
        chat.around_tool_call do |_call, &run|
          fibers << Fiber.current.object_id.to_s
          run.call
        end

        chat.ask('Go')

        tool_fibers = chat.messages.select(&:tool_result?).map(&:content)
        expect(Array.new(fibers.size) { fibers.pop }).to match_array(tool_fibers)
      end
    end
  end

  context 'with one tool call' do
    before do
      chat.with_tools(reader_tool('first', tenant_key))
      allow(chat.provider).to receive(:complete).and_return(calls('first'), answer)
    end

    it 'nests several blocks, the first registered outermost' do
      order = []
      chat.around_tool_call do |_call, &run|
        order << :outer_before
        run.call
        order << :outer_after
      end
      chat.around_tool_call do |_call, &run|
        order << :inner_before
        run.call
        order << :inner_after
      end
      chat.before_tool_call { order << :before }
      chat.after_tool_result { order << :after }

      chat.ask('Go')

      expect(order).to eq(%i[before outer_before inner_before inner_after outer_after after])
    end

    it 'returns the tool result from run and keeps it whatever the block returns' do
      returned = nil
      chat.around_tool_call do |_call, &run|
        returned = with_fiber_value(tenant_key, 'acme', &run)
        :ignored
      end

      chat.ask('Go')

      expect(returned).to eq('acme')
      expect(results).to eq(['acme'])
    end

    it 'returns the skipped call error from run to an outer block' do
      returned = nil
      chat.around_tool_call { |_call, &run| returned = run.call }
      chat.around_tool_call { |_call, &_run| nil }

      chat.ask('Go')

      expect(returned).to eq(error: 'The first call did not run.')
    end

    it 'skips the tool and tells the model when a block does not run it' do
      entered = false
      chat.around_tool_call { |_call, &_run| entered = true }

      chat.ask('Go')

      expect(entered).to be(true)
      expect(results.first).to include('did not run')
    end
  end

  describe 'the Agent macro' do
    after { Fiber[tenant_key] = nil }

    def agent_class(tool, &)
      Class.new(RubyLLM::Agent) do
        tools tool
        inputs :account
        class_exec(&)
      end
    end

    def ask(agent)
      allow(agent.chat.provider).to receive(:complete).and_return(calls('first'), answer)
      agent.ask('Go')
      agent.chat.messages.select(&:tool_result?).map(&:content)
    end

    it 'runs a method that yields to the tool, on the agent' do
      key = tenant_key
      klass = agent_class(reader_tool('first', key)) do
        around_tool_call :in_tenant

        define_method(:in_tenant) do |_call, &run|
          Fiber[key] = account
          run.call
        ensure
          Fiber[key] = nil
        end
      end

      expect(ask(klass.new(account: 'acme'))).to eq(['acme'])
    end

    it 'runs a block on the agent, given the tool as &run' do
      key = tenant_key
      klass = agent_class(reader_tool('first', key)) do
        around_tool_call do |_call, &run|
          Fiber[key] = account
          run.call
        end
      end

      expect(ask(klass.new(account: 'globex'))).to eq(['globex'])
    end

    it 'runs a block that takes only &run' do
      key = tenant_key
      klass = agent_class(reader_tool('first', key)) do
        around_tool_call do |&run|
          Fiber[key] = account
          run.call
        end
      end

      expect(ask(klass.new(account: 'initech'))).to eq(['initech'])
    end

    it 'runs the tool without the callback when a condition skips it' do
      key = tenant_key
      klass = agent_class(reader_tool('first', key)) do
        around_tool_call(if: -> { account }) do |_call, &run|
          Fiber[key] = 'set'
          run.call
        end
      end

      expect(ask(klass.new(account: nil))).to eq([''])
    end
  end
end
