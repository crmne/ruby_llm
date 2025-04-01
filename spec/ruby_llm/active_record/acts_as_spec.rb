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

  shared_examples 'a chainable chat method' do |method_name, *args|
    it "returns a Chat instance for ##{method_name}" do
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      result = chat.public_send(method_name, *args)
      expect(result).to be_a(Chat)
    end
  end

  shared_examples 'a chainable callback method' do |callback_name|
    it "supports #{callback_name} callback" do
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      result = chat.public_send(callback_name) do
        # no-op for testing
      end
      expect(result).to be_a(Chat)
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

  describe 'with_tools functionality' do
    it 'returns a Chat instance when using with_tool' do
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      with_tool_result = chat.with_tool(Calculator)
      expect(with_tool_result).to be_a(Chat)
    end

    it 'persists user messages' do
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      chat.with_tool(Calculator).ask("What's 2 + 2?")
      expect(chat.messages.where(role: 'user').first&.content).to eq("What's 2 + 2?")
    end
  end

  describe 'chainable methods' do
    it_behaves_like 'a chainable chat method', :with_tool, Calculator
    it_behaves_like 'a chainable chat method', :with_tools, Calculator
    it_behaves_like 'a chainable chat method', :with_model, 'gpt-4o-mini'
    it_behaves_like 'a chainable chat method', :with_temperature, 0.5

    it_behaves_like 'a chainable callback method', :on_new_message
    it_behaves_like 'a chainable callback method', :on_end_message

    it 'supports method chaining with tools' do
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      chat.with_tool(Calculator)
          .with_temperature(0.5)
      expect(chat).to be_a(Chat)
    end

    it 'persists messages after chaining' do
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      chat.with_tool(Calculator).ask("What's 3 * 3?")
      expect(chat.messages.where(role: 'user').first&.content).to eq("What's 3 * 3?")
    end
  end
end
