# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ToolConcurrency do
  let(:tool_calls) { { first: :first, second: :second } }
  let(:executor_calls) { Queue.new }
  let(:executor) do
    calls = executor_calls

    Object.new.tap do |object|
      object.define_singleton_method(:wrap) do |&block|
        calls << true
        block.call
      end
    end
  end

  def stub_rails_executor(executor)
    application = Object.new
    application.define_singleton_method(:executor) { executor }

    rails = Object.new
    rails.define_singleton_method(:application) { application }
    stub_const('Rails', rails)
  end

  it 'wraps threaded tool calls with the Rails executor' do
    stub_rails_executor(executor)

    results = described_class.run(:threads, tool_calls) { |tool_call| tool_call }

    expect(results).to eq([%i[first first], %i[second second]])
    expect(executor_calls.size).to eq(2)
  end

  it 'reports threaded tool call results as they finish' do
    completed = []
    delayed_tool_calls = {
      slow: { label: :slow, delay: 0.05 },
      fast: { label: :fast, delay: 0.01 }
    }

    results = described_class.run(
      :threads,
      delayed_tool_calls,
      on_result: ->(tool_call, result) { completed << [tool_call[:label], result] }
    ) do |tool_call|
      sleep tool_call[:delay]
      tool_call[:label]
    end

    expect(completed).to eq([%i[fast fast], %i[slow slow]])
    expect(results).to eq([
                            [delayed_tool_calls[:slow], :slow],
                            [delayed_tool_calls[:fast], :fast]
                          ])
  end

  it 'wraps fiber tool calls with the Rails executor' do
    stub_rails_executor(executor)

    results = described_class.run(:fibers, tool_calls) { |tool_call| tool_call }

    expect(results).to eq([%i[first first], %i[second second]])
    expect(executor_calls.size).to eq(2)
  end

  it 'reports fiber tool call results as they finish' do
    completed = []
    delayed_tool_calls = {
      slow: { label: :slow, delay: 0.05 },
      fast: { label: :fast, delay: 0.01 }
    }

    results = described_class.run(
      :fibers,
      delayed_tool_calls,
      on_result: ->(tool_call, result) { completed << [tool_call[:label], result] }
    ) do |tool_call|
      sleep tool_call[:delay]
      tool_call[:label]
    end

    expect(completed).to eq([%i[fast fast], %i[slow slow]])
    expect(results).to eq([
                            [delayed_tool_calls[:slow], :slow],
                            [delayed_tool_calls[:fast], :fast]
                          ])
  end
end
