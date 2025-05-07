# frozen_string_literal: true

require 'spec_helper'
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

      # the Bot* classes are used to test the class
      # renaming functionality of acts_as_*
      # They are supposed to be identical to the
      # non-Bot* classes, but with a different names
      # using Rails-canonical naming conventions.
      create_table :bot_chats do |t|
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

      create_table :bot_messages do |t|
        t.references :bot_chat
        t.string :role
        t.text :content
        t.string :model_id
        t.integer :input_tokens
        t.integer :output_tokens
        t.references :bot_tool_call
        t.timestamps
      end

      create_table :tool_calls do |t|
        t.references :message
        t.string :tool_call_id
        t.string :name
        t.json :arguments
        t.timestamps
      end

      create_table :bot_tool_calls do |t|
        t.references :bot_message
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

  module Assistants # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    class BotChat < ActiveRecord::Base # rubocop:disable RSpec/LeakyConstantDeclaration
      self.table_name = 'bot_chats'
      include RubyLLM::ActiveRecord::ActsAs
      acts_as_chat message_class: 'BotMessage', tool_call_class: 'BotToolCall'
    end
  end

  class Message < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    include RubyLLM::ActiveRecord::ActsAs
    acts_as_message
  end

  class BotMessage < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    include RubyLLM::ActiveRecord::ActsAs
    acts_as_message chat_class: 'Assistants::BotChat', tool_call_class: 'BotToolCall'
  end

  class ToolCall < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    include RubyLLM::ActiveRecord::ActsAs
    acts_as_tool_call
  end

  class BotToolCall < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    include RubyLLM::ActiveRecord::ActsAs
    acts_as_tool_call message_class: 'BotMessage'
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
      [Chat, Assistants::BotChat].each do |chat_class|
        chat = chat_class.create!(model_id: 'gpt-4.1-nano')
        result = chat.public_send(method_name, *args)
        expect(result).to be_a(chat_class)
      end
    end
  end

  shared_examples 'a chainable callback method' do |callback_name|
    it "supports #{callback_name} callback" do # rubocop:disable RSpec/ExampleLength
      [Chat, Assistants::BotChat].each do |chat_class|
        chat = chat_class.create!(model_id: 'gpt-4.1-nano')
        result = chat.public_send(callback_name) do
          # no-op for testing
        end
        expect(result).to be_a(chat_class)
      end
    end
  end

  it 'persists chat history' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
    chat = Chat.create!(model_id: 'gpt-4.1-nano')
    chat.ask("What's your favorite Ruby feature?")

    expect(chat.messages.count).to eq(2)
    expect(chat.messages.first.role).to eq('user')
    expect(chat.messages.last.role).to eq('assistant')
    expect(chat.messages.last.content).to be_present
    expect(chat.messages.last.input_tokens).to be_positive
    expect(chat.messages.last.output_tokens).to be_positive
  end

  it 'to_llm returns the correct amount of messages' do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
    chat = Chat.create!(model_id: 'gpt-4.1-nano')
    chat.ask("What's your favorite Ruby feature?")

    expect(chat.messages.count).to eq(2)
    expect(chat.to_llm.messages.count).to eq(2)

    chat.ask('Again?')

    expect(chat.messages.count).to eq(4)
    expect(chat.to_llm.messages.count).to eq(4)
  end

  it 'persists tool calls' do # rubocop:disable RSpec/MultipleExpectations
    chat = Chat.create!(model_id: 'gpt-4.1-nano')
    chat.with_tool(Calculator)

    chat.ask("What's 123 * 456?")

    expect(chat.messages.count).to be >= 3 # User message, tool call, and final response
    expect(chat.messages.any?(&:tool_calls)).to be true
  end

  describe 'with_tools functionality' do
    it 'returns a Chat instance when using with_tool' do
      [Chat, Assistants::BotChat].each do |chat_class|
        chat = chat_class.create!(model_id: 'gpt-4.1-nano')
        with_tool_result = chat.with_tool(Calculator)
        expect(with_tool_result).to be_a(chat_class)
      end
    end

    it 'persists user messages' do
      chat = Chat.create!(model_id: 'gpt-4.1-nano')
      chat.with_tool(Calculator).ask("What's 2 + 2?")
      expect(chat.messages.where(role: 'user').first&.content).to eq("What's 2 + 2?")
    end
  end

  describe 'chainable methods' do
    it_behaves_like 'a chainable chat method', :with_tool, Calculator
    it_behaves_like 'a chainable chat method', :with_tools, Calculator
    it_behaves_like 'a chainable chat method', :with_model, 'gpt-4.1-nano'
    it_behaves_like 'a chainable chat method', :with_temperature, 0.5

    it_behaves_like 'a chainable callback method', :on_new_message
    it_behaves_like 'a chainable callback method', :on_end_message

    it 'supports method chaining with tools' do # rubocop:disable RSpec/ExampleLength
      [Chat, Assistants::BotChat].each do |chat_class|
        chat = chat_class.create!(model_id: 'gpt-4.1-nano')
        chat.with_tool(Calculator)
            .with_temperature(0.5)
        expect(chat).to be_a(chat_class)
      end
    end

    it 'persists messages after chaining' do
      chat = Chat.create!(model_id: 'gpt-4.1-nano')
      chat.with_tool(Calculator).ask("What's 3 * 3?")
      expect(chat.messages.where(role: 'user').first&.content).to eq("What's 3 * 3?")
    end

    it 'persists system messages' do # rubocop:disable RSpec/MultipleExpectations
      chat = Chat.create!(model_id: 'gpt-4.1-nano')
      chat.with_instructions('You are a Ruby expert')

      expect(chat.messages.first.role).to eq('system')
      expect(chat.messages.first.content).to eq('You are a Ruby expert')
    end

    it 'optionally replaces existing system messages' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      chat = Chat.create!(model_id: 'gpt-4.1-nano')

      # Add first instruction
      chat.with_instructions('Be helpful')
      expect(chat.messages.where(role: 'system').count).to eq(1)

      # Add second instruction without replace
      chat.with_instructions('Be concise')
      expect(chat.messages.where(role: 'system').count).to eq(2)

      # Replace all instructions
      chat.with_instructions('Be awesome', replace: true)
      expect(chat.messages.where(role: 'system').count).to eq(1)
      expect(chat.messages.find_by(role: 'system').content).to eq('Be awesome')
    end
  end

  describe 'acts_as_chat error handling' do
    let!(:chat_record) { Chat.create!(model_id: 'gpt-4.1-nano') }
    let(:provider_instance) { RubyLLM::Provider.for(chat_record.model_id) }
    let(:api_base) { provider_instance.api_base(RubyLLM.config) }
    let(:completion_url_regex) { %r{#{api_base}/#{provider_instance.completion_url}} }

    before do
      stub_request(:post, completion_url_regex)
        .to_return(
          status: 500,
          body: { error: { message: 'API go boom' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'destroys the empty assistant message record on API failure' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      expect do
        chat_record.ask('This one will fail')
      end.to raise_error(RubyLLM::ServerError, /API go boom/)
      expect(Message.where(chat_id: chat_record.id).count).to eq(1)
      remaining_message = Message.find_by(chat_id: chat_record.id)
      expect(remaining_message.role).to eq('user')
      expect(remaining_message.content).to eq('This one will fail')
      expect(Message.where(chat_id: chat_record.id, role: 'assistant').count).to eq(0)
    end
  end
end
