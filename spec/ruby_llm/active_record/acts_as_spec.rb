# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'
require 'active_record'
require 'ruby_llm/active_record/acts_as'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  before do
    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3',
      database: ':memory:'
    )

    ActiveRecord::Schema.define do
      create_table :chats do |t|
        t.string :model_id
        t.timestamps
      end

      create_table :messages do |t|
        t.references :chat
        t.string :role
        t.text :content
        t.string :model_id
        t.integer :input_tokens
        t.integer :output_tokens
        t.references :tool_call
        t.timestamps
      end

      create_table :tool_calls do |t|
        t.references :message
        t.string :tool_call_id
        t.string :name
        t.json :arguments
        t.timestamps
      end
    end
  end

  class Chat < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    include RubyLLM::ActiveRecord::ActsAs
    acts_as_chat
  end

  class Message < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    include RubyLLM::ActiveRecord::ActsAs
    acts_as_message
  end

  class ToolCall < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    include RubyLLM::ActiveRecord::ActsAs
    acts_as_tool_call
  end

  class Calculator < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Performs basic arithmetic'

    param :expression,
          type: :string,
          desc: 'Math expression to evaluate'

    def execute(expression:)
      eval(expression).to_s # rubocop:disable Security/Eval
    rescue StandardError => e
      "Error: #{e.message}"
    end
  end

  it 'persists chat history' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
    chat = Chat.create!(model_id: 'gpt-4o-mini')
    chat.ask("What's your favorite Ruby feature?")

    expect(chat.messages.count).to eq(2)
    expect(chat.messages.first.role).to eq('user')
    expect(chat.messages.last.role).to eq('assistant')
    expect(chat.messages.last.content).to be_present
    expect(chat.messages.last.input_tokens).to be_positive
    expect(chat.messages.last.output_tokens).to be_positive
  end

  it 'persists tool calls' do # rubocop:disable RSpec/MultipleExpectations
    chat = Chat.create!(model_id: 'gpt-4o-mini')
    chat.with_tool(Calculator)

    chat.ask("What's 123 * 456?")

    expect(chat.messages.count).to be >= 3 # User message, tool call, and final response
    expect(chat.messages.any?(&:tool_calls)).to be true
  end
  
  it 'persists user messages when using with_tools' do # rubocop:disable RSpec/MultipleExpectations
    chat = Chat.create!(model_id: 'gpt-4o-mini')
    
    # Test the class of the return value
    with_tool_result = chat.with_tool(Calculator)
    expect(with_tool_result).to be_a(Chat)
    
    # When using with_tools in a method chain, user messages should still be saved
    chat.with_tool(Calculator).ask("What's 2 + 2?")
    
    expect(chat.messages.count).to be >= 2 # At least user message and assistant response
    expect(chat.messages.where(role: 'user').count).to eq(1)
    expect(chat.messages.where(role: 'user').first&.content).to eq("What's 2 + 2?")
  end
  
  it 'maintains ActiveRecord model for all chainable methods' do # rubocop:disable RSpec/MultipleExpectations
    chat = Chat.create!(model_id: 'gpt-4o-mini')
    
    # Test that all chainable methods return the ActiveRecord model
    expect(chat.with_tool(Calculator)).to be_a(Chat)
    expect(chat.with_tools(Calculator)).to be_a(Chat)
    expect(chat.with_model('gpt-4o-mini')).to be_a(Chat)
    expect(chat.with_temperature(0.5)).to be_a(Chat)
    expect(chat.on_new_message {}).to be_a(Chat)
    expect(chat.on_end_message {}).to be_a(Chat)
    
    # Complex chain
    result = chat.with_tool(Calculator)
                 .with_temperature(0.7)
                 .on_new_message {}
                 .on_end_message {}
    
    expect(result).to be_a(Chat)
    
    # And it should still save the message when used at the end of a chain
    chat.with_tool(Calculator)
        .with_temperature(0.5)
        .ask("What's 3 * 3?")
    
    expect(chat.messages.where(role: 'user').count).to eq(1)
    expect(chat.messages.where(role: 'user').first&.content).to eq("What's 3 * 3?")
  end
end
