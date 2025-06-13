# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  let(:model) { 'gpt-4.1-nano' }

  class Calculator < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Performs basic arithmetic'
    param :expression, type: :string, desc: 'Math expression to evaluate'

    def execute(expression:)
      eval(expression).to_s # rubocop:disable Security/Eval
    rescue StandardError => e
      "Error: #{e.message}"
    end
  end

  # Basic functionality tests using dummy app models
  describe 'basic chat functionality' do
    it 'persists chat history' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      chat = Chat.create!(model_id: model)
      chat.ask("What's your favorite Ruby feature?")

      expect(chat.messages.count).to eq(2)
      expect(chat.messages.first.role).to eq('user')
      expect(chat.messages.last.role).to eq('assistant')
      expect(chat.messages.last.content).to be_present
      # Update the chat to simulate a change
      chat.touch
      expect(chat.updated_at).to eq(chat.messages.last.chat.updated_at)
    end

    it 'tracks token usage' do # rubocop:disable RSpec/MultipleExpectations
      chat = Chat.create!(model_id: 'gpt-4.1-nano')
      chat.ask('Hello')

      message = chat.messages.last
      expect(message.input_tokens).to be_positive
      expect(message.output_tokens).to be_positive
    end
  end

  describe 'system messages' do
    it 'persists system messages' do # rubocop:disable RSpec/MultipleExpectations
      chat = Chat.create!(model_id: model)
      chat.with_instructions('You are a Ruby expert')

      expect(chat.messages.first.role).to eq('system')
      expect(chat.messages.first.content).to eq('You are a Ruby expert')
    end

    it 'replaces system messages when requested' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      chat = Chat.create!(model_id: model)

      chat.with_instructions('Be helpful')
      chat.with_instructions('Be concise')
      expect(chat.messages.where(role: 'system').count).to eq(2)

      chat.with_instructions('Be awesome', replace: true)
      expect(chat.messages.where(role: 'system').count).to eq(1)
      expect(chat.messages.find_by(role: 'system').content).to eq('Be awesome')
    end
  end

  describe 'tool usage' do
    it 'persists tool calls' do # rubocop:disable RSpec/MultipleExpectations
      chat = Chat.create!(model_id: model)
      chat.with_tool(Calculator)

      chat.ask("What's 123 * 456?")

      expect(chat.messages.count).to be >= 3
      expect(chat.messages.any? { |m| m.tool_calls.any? }).to be true
    end

    it 'returns the chat instance for chaining' do
      chat = Chat.create!(model_id: model)

      result = chat.with_tool(Calculator)
      expect(result).to eq(chat)
    end
  end

  describe 'model switching' do
    it 'allows changing models mid-conversation' do
      chat = Chat.create!(model_id: model)
      chat.ask('Hello')

      chat.with_model('claude-3-5-haiku-20241022')
      expect(chat.reload.model_id).to eq('claude-3-5-haiku-20241022')
    end
  end

  describe 'error handling' do
    it 'destroys empty assistant messages on API failure' do # rubocop:disable RSpec/MultipleExpectations
      chat = Chat.create!(model_id: model)

      # Stub the API to fail
      allow_any_instance_of(RubyLLM::Chat).to receive(:complete).and_raise(RubyLLM::Error) # rubocop:disable RSpec/AnyInstance

      expect { chat.ask('This will fail') }.to raise_error(RubyLLM::Error)

      # Should only have the user message
      expect(chat.messages.count).to eq(1)
      expect(chat.messages.first.role).to eq('user')
    end
  end

  # Custom configuration tests with inline models
  describe 'custom configurations' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      # Create additional tables for testing edge cases
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :bot_chats, force: true do |t|
          t.string :model_id
          t.timestamps
        end

        ActiveRecord::Migration.create_table :bot_messages, force: true do |t|
          t.references :bot_chat
          t.string :role
          t.text :content
          t.string :model_id
          t.integer :input_tokens
          t.integer :output_tokens
          t.references :bot_tool_call
          t.timestamps
        end

        ActiveRecord::Migration.create_table :bot_tool_calls, force: true do |t|
          t.references :bot_message
          t.string :tool_call_id
          t.string :name
          t.json :arguments
          t.timestamps
        end
      end
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      ActiveRecord::Migration.suppress_messages do
        if ActiveRecord::Base.connection.table_exists?(:bot_tool_calls)
          ActiveRecord::Migration.drop_table :bot_tool_calls
        end
        ActiveRecord::Migration.drop_table :bot_messages if ActiveRecord::Base.connection.table_exists?(:bot_messages)
        ActiveRecord::Migration.drop_table :bot_chats if ActiveRecord::Base.connection.table_exists?(:bot_chats)
      end
    end

    # Define test models inline
    module Assistants # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
      class BotChat < ActiveRecord::Base # rubocop:disable RSpec/LeakyConstantDeclaration
        self.table_name = 'bot_chats'
        include RubyLLM::ActiveRecord::ActsAs
        acts_as_chat message_class: 'BotMessage', tool_call_class: 'BotToolCall'
      end
    end

    class BotMessage < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
      include RubyLLM::ActiveRecord::ActsAs
      acts_as_message chat_class: 'Assistants::BotChat', tool_call_class: 'BotToolCall'
    end

    class BotToolCall < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
      include RubyLLM::ActiveRecord::ActsAs
      acts_as_tool_call message_class: 'BotMessage'
    end

    describe 'namespaced chat models' do
      it 'works with namespaced classes and custom associations' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        bot_chat = Assistants::BotChat.create!(model_id: model)
        bot_chat.ask("What's 2 + 2?")

        expect(bot_chat.messages.count).to eq(2)
        expect(bot_chat.messages.first).to be_a(BotMessage)
        expect(bot_chat.messages.first.role).to eq('user')
        expect(bot_chat.messages.last.role).to eq('assistant')
        expect(bot_chat.messages.last.content).to be_present
      end

      it 'persists tool calls with custom classes' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        bot_chat = Assistants::BotChat.create!(model_id: model)
        bot_chat.with_tool(Calculator)

        bot_chat.ask("What's 123 * 456?")

        expect(bot_chat.messages.count).to be >= 3
        tool_call_message = bot_chat.messages.find { |m| m.tool_calls.any? }
        expect(tool_call_message).to be_present
        expect(tool_call_message.tool_calls.first).to be_a(BotToolCall)
      end

      it 'handles system messages correctly' do # rubocop:disable RSpec/MultipleExpectations
        bot_chat = Assistants::BotChat.create!(model_id: model)
        bot_chat.with_instructions('You are a helpful bot')

        expect(bot_chat.messages.first.role).to eq('system')
        expect(bot_chat.messages.first.content).to eq('You are a helpful bot')
        expect(bot_chat.messages.first).to be_a(BotMessage)
      end

      it 'allows model switching' do
        bot_chat = Assistants::BotChat.create!(model_id: model)
        bot_chat.ask('Hello')

        bot_chat.with_model('claude-3-5-haiku-20241022')
        expect(bot_chat.reload.model_id).to eq('claude-3-5-haiku-20241022')
      end
    end

    describe 'to_llm conversion' do
      it 'correctly converts custom messages to RubyLLM format' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        bot_chat = Assistants::BotChat.create!(model_id: model)
        bot_message = bot_chat.messages.create!(
          role: 'user',
          content: 'Test message',
          input_tokens: 10,
          output_tokens: 20
        )

        llm_message = bot_message.to_llm
        expect(llm_message).to be_a(RubyLLM::Message)
        expect(llm_message.role).to eq(:user)
        expect(llm_message.content).to eq('Test message')
        expect(llm_message.input_tokens).to eq(10)
        expect(llm_message.output_tokens).to eq(20)
      end

      it 'correctly converts tool calls' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        bot_chat = Assistants::BotChat.create!(model_id: model)
        bot_message = bot_chat.messages.create!(role: 'assistant', content: 'I need to calculate something')

        bot_message.tool_calls.create!(
          tool_call_id: 'call_123',
          name: 'calculator',
          arguments: { expression: '2 + 2' }
        )

        llm_message = bot_message.to_llm
        expect(llm_message.tool_calls).to have_key('call_123')

        llm_tool_call = llm_message.tool_calls['call_123']
        expect(llm_tool_call).to be_a(RubyLLM::ToolCall)
        expect(llm_tool_call.id).to eq('call_123')
        expect(llm_tool_call.name).to eq('calculator')
        expect(llm_tool_call.arguments).to eq({ 'expression' => '2 + 2' })
      end
    end
  end

  describe 'attachment handling' do
    let(:image_path) { File.expand_path('../../fixtures/ruby.png', __dir__) }
    let(:pdf_path) { File.expand_path('../../fixtures/sample.pdf', __dir__) }

    def uploaded_file(path, type)
      filename = File.basename(path)
      extension = File.extname(filename)
      name = File.basename(filename, extension)

      tempfile = Tempfile.new([name, extension])
      tempfile.binmode

      # Copy content from the real file to the Tempfile
      File.open(path, 'rb') do |real_file_io|
        tempfile.write(real_file_io.read)
      end

      tempfile.rewind # Prepare Tempfile for reading from the beginning

      ActionDispatch::Http::UploadedFile.new(
        tempfile: tempfile,
        filename: File.basename(tempfile),
        type: type
      )
    end

    it 'converts ActiveStorage attachments to RubyLLM Content' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      chat = Chat.create!(model_id: model)

      message = chat.messages.create!(role: 'user', content: 'Check this out')
      message.attachments.attach(
        io: File.open(image_path),
        filename: 'ruby.png',
        content_type: 'image/png'
      )

      llm_message = message.to_llm
      expect(llm_message.content).to be_a(RubyLLM::Content)
      expect(llm_message.content.attachments.first.mime_type).to eq('image/png')
    end

    it 'handles multiple attachments' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      chat = Chat.create!(model_id: model)

      image_upload = uploaded_file(image_path, 'image/png')
      pdf_upload = uploaded_file(pdf_path, 'application/pdf')

      response = chat.ask('Analyze these', with: [image_upload, pdf_upload])

      user_message = chat.messages.find_by(role: 'user')
      expect(user_message.attachments.count).to eq(2)
      expect(response.content).to be_present
    end

    it 'handles attachments in ask method' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      chat = Chat.create!(model_id: model)

      image_upload = uploaded_file(image_path, 'image/png')

      response = chat.ask('What do you see?', with: image_upload)

      user_message = chat.messages.find_by(role: 'user')
      expect(user_message.attachments.count).to eq(1)
      expect(response.content).to be_present
    end

    describe 'attachment types' do
      it 'handles images' do # rubocop:disable RSpec/ExampleLength
        chat = Chat.create!(model_id: model)
        message = chat.messages.create!(role: 'user', content: 'Image test')

        message.attachments.attach(
          io: File.open(image_path),
          filename: 'test.png',
          content_type: 'image/png'
        )

        llm_message = message.to_llm
        attachment = llm_message.content.attachments.first
        expect(attachment.type).to eq(:image)
      end

      it 'handles PDFs' do # rubocop:disable RSpec/ExampleLength
        chat = Chat.create!(model_id: model)
        message = chat.messages.create!(role: 'user', content: 'PDF test')

        message.attachments.attach(
          io: File.open(pdf_path),
          filename: 'test.pdf',
          content_type: 'application/pdf'
        )

        llm_message = message.to_llm
        attachment = llm_message.content.attachments.first
        expect(attachment.type).to eq(:pdf)
      end
    end
  end
end
