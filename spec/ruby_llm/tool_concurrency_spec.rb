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

  it 'wraps fiber tool calls with the Rails executor' do
    stub_rails_executor(executor)

    results = described_class.run(:fibers, tool_calls) { |tool_call| tool_call }

    expect(results).to eq([%i[first first], %i[second second]])
    expect(executor_calls.size).to eq(2)
  end
end
