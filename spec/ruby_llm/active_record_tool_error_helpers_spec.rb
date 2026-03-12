# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ActiveRecord do
  describe RubyLLM::ActiveRecord::MessageMethods do
    subject(:message_instance) { message_class.new }

    let(:message_class) do
      Class.new do
        include RubyLLM::ActiveRecord::MessageMethods

        attr_accessor :content
      end
    end

    it 'extracts error from hash content' do
      message_instance.content = { error: 'tool failed' }
      expect(message_instance.tool_error_message).to eq('tool failed')
    end

    it 'extracts error from JSON string content' do
      message_instance.content = '{"error":"tool failed"}'
      expect(message_instance.tool_error_message).to eq('tool failed')
    end

    it 'returns nil for invalid content' do
      message_instance.content = 'not-json'
      expect(message_instance.tool_error_message).to be_nil
    end
  end

  describe RubyLLM::ActiveRecord::ToolCallMethods do
    subject(:tool_call_instance) { tool_call_class.new }

    let(:tool_call_class) do
      Class.new do
        include RubyLLM::ActiveRecord::ToolCallMethods

        attr_accessor :arguments
      end
    end

    it 'extracts error from hash arguments' do
      tool_call_instance.arguments = { error: 'bad params' }
      expect(tool_call_instance.tool_error_message).to eq('bad params')
    end

    it 'extracts error from JSON string arguments' do
      tool_call_instance.arguments = '{"error":"bad params"}'
      expect(tool_call_instance.tool_error_message).to eq('bad params')
    end

    it 'returns nil for non-error arguments' do
      tool_call_instance.arguments = { city: 'Berlin' }
      expect(tool_call_instance.tool_error_message).to be_nil
    end
  end
end
