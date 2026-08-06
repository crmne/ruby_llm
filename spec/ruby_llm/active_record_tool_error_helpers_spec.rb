# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/active_record/message_methods'

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
end
