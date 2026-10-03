# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::Chat::ToolConcurrency do
  include_context 'with configured RubyLLM'

  let(:tool_calls) { %w[a b c].to_h { |id| [id, RubyLLM::ToolCall.new(id:, name: 'lookup', arguments: {})] } }

  def with_isolation(level)
    previous = ActiveSupport::IsolatedExecutionState.isolation_level
    ActiveSupport::IsolatedExecutionState.isolation_level = level
    yield
  ensure
    ActiveSupport::IsolatedExecutionState.isolation_level = previous
  end

  def abandoned_connections
    ActiveRecord::Base.connection_pool.connections.count do |connection|
      connection.in_use? && !connection.owner.alive?
    end
  end

  def reported_errors
    reports = []
    subscriber = Object.new
    subscriber.define_singleton_method(:report) { |error, **| reports << error }
    Rails.error.subscribe(subscriber)
    yield
    reports
  ensure
    Rails.error.unsubscribe(subscriber)
  end

  it 'leaves an error a tool thread raised for the caller to report' do
    reports = reported_errors do
      expect { described_class.run(:threads, tool_calls) { raise ArgumentError, 'tool blew up' } }
        .to raise_error(ArgumentError, 'tool blew up')
    end

    expect(reports).to be_empty
  end

  def run_rounds(count)
    count.times do
      described_class.run(:fibers, tool_calls,
                          on_result: ->(*) { ActiveRecord::Base.connection.select_value('SELECT 1') }) do |call|
        ActiveRecord::Base.connection_pool.with_connection { |connection| connection.select_value('SELECT 1') }
        call.id
      end
    end
  end

  context 'when Rails isolates execution state per fiber' do
    around { |example| with_isolation(:fiber) { example.run } }

    it 'returns the connections results leased inside a reactor' do
      ActiveRecord::Base.connection_pool.reap
      in_reactor { Rails.application.executor.wrap { run_rounds(3) } }

      expect(abandoned_connections).to eq(0)
    end

    it 'returns the connections results leased outside a reactor' do
      ActiveRecord::Base.connection_pool.reap
      Rails.application.executor.wrap { run_rounds(3) }

      expect(abandoned_connections).to eq(0)
    end

    it 'leaves an error a tool fiber raised for the caller to report' do
      reports = reported_errors do
        expect { described_class.run(:fibers, tool_calls) { raise ArgumentError, 'tool blew up' } }
          .to raise_error(ArgumentError, 'tool blew up')
      end

      expect(reports).to be_empty
    end

    it 'returns the connections a fiber job leases while persisting results' do
      stub_const('CountChats', Class.new(RubyLLM::Tool) do
        description 'Counts chats'

        def execute
          sleep 0.01
          Chat.count
        end
      end)
      rounds = Array.new(3) do
        calls = Array.new(3) { RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: 'count_chats') }
        RubyLLM::Message.new(role: :assistant, content: '', tool_calls: calls.to_h { |call| [call.id, call] })
      end
      ActiveRecord::Base.connection_pool.reap

      in_reactor do
        Rails.application.executor.wrap do
          chat = Chat.create!(model: model_for(:openai)).with_tools(CountChats)
                     .with_tool_options(concurrency: :fibers)
                     .after_message { Message.connection.select_value('SELECT 1') }
          allow(chat.to_llm.provider).to receive(:complete)
            .and_return(*rounds, RubyLLM::Message.new(role: :assistant, content: 'Counted'))

          expect(chat.ask('Count the chats three times').content).to eq('Counted')
          expect(chat.messages.where(role: 'tool').count).to eq(9)
        end
      end

      expect(abandoned_connections).to eq(0)
    end
  end

  context 'when Rails isolates execution state per thread' do
    around { |example| with_isolation(:thread) { example.run } }

    it 'runs fiber tool calls in the execution state of a caller outside the executor' do
      stub_const('Workspace', Class.new(ActiveSupport::CurrentAttributes) { attribute :slug })
      Workspace.slug = 'acme'
      seen = Queue.new

      described_class.run(:fibers, tool_calls) do |call|
        sleep 0.01
        seen << Workspace.slug
        call.id
      end

      expect(Array.new(3) { seen.pop }).to all(eq('acme'))
      expect(Workspace.slug).to eq('acme')
    ensure
      Workspace.reset
    end
  end
end
