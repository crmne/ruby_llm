# frozen_string_literal: true

require 'rails_helper'

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
    it 'persists chat history' do
      chat = Chat.create!(model: model)
      chat.ask("What's your favorite Ruby feature?")

      expect(chat.messages.count).to eq(2)
      expect(chat.messages.first.role).to eq('user')
      expect(chat.messages.last.role).to eq('assistant')
      expect(chat.messages.last.content).to be_present
      # Update the chat to simulate a change
      chat.touch
      expect(chat.updated_at).to eq(chat.messages.last.chat.updated_at)
    end

    it 'tracks token usage' do
      chat = Chat.create!(model: 'gpt-4.1-nano')
      chat.ask('Hello')

      message = chat.messages.last
      expect(message.input_tokens).to be_positive
      expect(message.output_tokens).to be_positive
    end
  end

  describe 'system messages' do
    it 'persists system messages' do
      chat = Chat.create!(model: model)
      chat.with_instructions('You are a Ruby expert')

      expect(chat.messages.first.role).to eq('system')
      expect(chat.messages.first.content).to eq('You are a Ruby expert')
    end

    it 'replaces system messages when requested' do
      chat = Chat.create!(model: model)

      chat.with_instructions('Be helpful')
      chat.with_instructions('Be concise')
      expect(chat.messages.where(role: 'system').count).to eq(2)

      chat.with_instructions('Be awesome', replace: true)
      expect(chat.messages.where(role: 'system').count).to eq(1)
      expect(chat.messages.find_by(role: 'system').content).to eq('Be awesome')
    end
  end

  describe 'tool usage' do
    it 'persists tool calls' do
      chat = Chat.create!(model: model)
      chat.with_tool(Calculator)

      chat.ask("What's 123 * 456?")

      expect(chat.messages.count).to be >= 3
      expect(chat.messages.any? { |m| m.tool_calls.any? }).to be true
    end

    it 'returns the chat instance for chaining' do
      chat = Chat.create!(model: model)

      result = chat.with_tool(Calculator)
      expect(result).to eq(chat)
    end
  end

  describe 'model switching' do
    it 'allows changing models mid-conversation' do
      chat = Chat.create!(model: model)
      chat.ask('Hello')

      chat.with_model('claude-3-5-haiku-20241022')
      expect(chat.reload.model_id).to eq('claude-3-5-haiku-20241022')
    end
  end

  describe 'default model' do
    it 'uses config default when no model specified' do
      chat = Chat.create!
      chat.ask('Hello')

      expect(chat.reload.model_id).to eq(RubyLLM.config.default_model)
      expect(chat.messages.count).to eq(2)
    end
  end

  describe 'model associations' do
    context 'when model registry is configured' do
      before do
        # Only set up if Model class exists (from dummy app)
        next unless defined?(Model)

        # Model should already exist from before(:all) which loaded from JSON
      end

      it 'associates chat with model' do
        skip 'Model not available' unless defined?(Model) && Model.table_exists?

        chat = Chat.create!(model: 'gpt-4.1-nano')
        expect(chat).to respond_to(:model)
        expect(chat.model&.name).to eq('GPT-4.1 Nano') if chat.model
      end

      it 'associates messages with model' do
        skip 'Model not available' unless defined?(Model) && Model.table_exists?

        chat = Chat.create!(model: 'gpt-4.1-nano')
        chat.ask('Hello')

        message = chat.messages.last
        expect(message).to respond_to(:model) if defined?(Message.model)
      end
    end
  end

  describe 'structured output' do
    it 'supports with_schema for structured responses' do
      chat = Chat.create!(model: model)

      schema = {
        type: 'object',
        properties: {
          name: { type: 'string' },
          age: { type: 'integer' }
        },
        required: %w[name age],
        additionalProperties: false
      }

      result = chat.with_schema(schema)
      expect(result).to eq(chat) # Should return self for chaining

      response = chat.ask('Generate a person named Alice who is 25 years old')

      # The response content should be parsed JSON
      expect(response.content).to be_a(Hash)
      expect(response.content['name']).to eq('Alice')
      expect(response.content['age']).to eq(25)

      # Check that the message is saved in ActiveRecord with valid JSON
      saved_message = chat.messages.last
      expect(saved_message.role).to eq('assistant')
      expect(saved_message.content).to be_a(String)

      # The saved content should be parseable JSON
      parsed_saved_content = JSON.parse(saved_message.content)
      expect(parsed_saved_content).to be_a(Hash)
      expect(parsed_saved_content['name']).to eq('Alice')
      expect(parsed_saved_content['age']).to eq(25)
    end
  end

  describe 'parameter passing' do
    it 'supports with_params for provider-specific parameters' do
      chat = Chat.create!(model: model)

      result = chat.with_params(max_tokens: 100, temperature: 0.5)
      expect(result).to eq(chat) # Should return self for chaining

      # Verify params are passed through
      llm_chat = chat.instance_variable_get(:@chat)
      expect(llm_chat.params).to eq(max_tokens: 100, temperature: 0.5)
    end
  end

  describe 'tool functionality' do
    it 'supports with_tools for multiple tools' do
      chat = Chat.create!(model: model)

      # Define a second tool for testing
      weather_tool = Class.new(RubyLLM::Tool) do
        def self.name = 'weather'
        def self.description = 'Get weather'
        def execute = 'Sunny'
      end

      result = chat.with_tools(Calculator, weather_tool)
      expect(result).to eq(chat) # Should return self for chaining

      # Verify tools are registered
      llm_chat = chat.instance_variable_get(:@chat)
      expect(llm_chat.tools.keys).to include(:calculator, :weather)
    end

    it 'handles halt mechanism in tools' do
      # Define a tool that uses halt
      stub_const('HaltingTool', Class.new(RubyLLM::Tool) do
        description 'A tool that halts'
        param :input, desc: 'Input text'

        def execute(input:)
          halt("Halted with: #{input}")
        end
      end)

      chat = Chat.create!(model: model)
      chat.with_tool(HaltingTool)

      # Mock the tool execution to test halt behavior
      allow_any_instance_of(HaltingTool).to receive(:execute).and_return( # rubocop:disable RSpec/AnyInstance
        RubyLLM::Tool::Halt.new('Halted response')
      )

      # When a tool returns halt, the conversation should stop
      response = chat.ask("Use the halting tool with 'test'")

      # The response should be the halt result, not additional AI commentary
      expect(response).to be_a(RubyLLM::Tool::Halt)
      expect(response.content).to eq('Halted response')
    end
  end

  describe 'custom headers' do
    it 'supports with_headers for custom HTTP headers' do
      chat = Chat.create!(model: model)

      result = chat.with_headers('X-Custom-Header' => 'test-value')
      expect(result).to eq(chat) # Should return self for chaining

      # Verify the headers are passed through to the underlying chat
      llm_chat = chat.instance_variable_get(:@chat)
      expect(llm_chat.headers).to eq('X-Custom-Header' => 'test-value')
    end

    it 'allows chaining with_headers with other methods' do
      chat = Chat.create!(model: model)

      result = chat
               .with_temperature(0.5)
               .with_headers('X-Test' => 'value')
               .with_tool(Calculator)

      expect(result).to eq(chat)

      llm_chat = chat.instance_variable_get(:@chat)
      expect(llm_chat.headers).to eq('X-Test' => 'value')
    end
  end

  describe 'error handling' do
    it 'destroys empty assistant messages on API failure' do
      chat = Chat.create!(model: model)

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
        acts_as_chat messages: :bot_messages
      end
    end

    class BotMessage < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
      acts_as_message chat: :bot_chat, chat_class: 'Assistants::BotChat', tool_calls: :bot_tool_calls
    end

    class BotToolCall < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
      acts_as_tool_call message: :bot_message
    end

    describe 'namespaced chat models' do
      it 'works with namespaced classes and custom associations' do
        bot_chat = Assistants::BotChat.create!(model: model)
        bot_chat.ask("What's 2 + 2?")

        expect(bot_chat.bot_messages.count).to eq(2)
        expect(bot_chat.bot_messages.first).to be_a(BotMessage)
        expect(bot_chat.bot_messages.first.role).to eq('user')
        expect(bot_chat.bot_messages.last.role).to eq('assistant')
        expect(bot_chat.bot_messages.last.content).to be_present
      end

      it 'persists tool calls with custom classes' do
        bot_chat = Assistants::BotChat.create!(model: model)
        bot_chat.with_tool(Calculator)

        bot_chat.ask("What's 123 * 456?")

        expect(bot_chat.bot_messages.count).to be >= 3
        tool_call_message = bot_chat.bot_messages.find { |m| m.bot_tool_calls.any? }
        expect(tool_call_message).to be_present
        expect(tool_call_message.bot_tool_calls.first).to be_a(BotToolCall)
      end

      it 'handles system messages correctly' do
        bot_chat = Assistants::BotChat.create!(model: model)
        bot_chat.with_instructions('You are a helpful bot')

        expect(bot_chat.bot_messages.first.role).to eq('system')
        expect(bot_chat.bot_messages.first.content).to eq('You are a helpful bot')
        expect(bot_chat.bot_messages.first).to be_a(BotMessage)
      end

      it 'allows model switching' do
        bot_chat = Assistants::BotChat.create!(model: model)
        bot_chat.ask('Hello')

        bot_chat.with_model('claude-3-5-haiku-20241022')
        expect(bot_chat.reload.model_id).to eq('claude-3-5-haiku-20241022')
      end
    end

    describe 'to_llm conversion' do
      it 'correctly converts custom messages to RubyLLM format' do
        bot_chat = Assistants::BotChat.create!(model: model)
        bot_message = bot_chat.bot_messages.create!(
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

      it 'correctly converts tool calls' do
        bot_chat = Assistants::BotChat.create!(model: model)
        bot_message = bot_chat.bot_messages.create!(role: 'assistant', content: 'I need to calculate something')

        bot_message.bot_tool_calls.create!(
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

    it 'converts ActiveStorage attachments to RubyLLM Content' do
      chat = Chat.create!(model: model)

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

    it 'handles multiple attachments' do
      chat = Chat.create!(model: model)

      image_upload = uploaded_file(image_path, 'image/png')
      pdf_upload = uploaded_file(pdf_path, 'application/pdf')

      response = chat.ask('Analyze these', with: [image_upload, pdf_upload])

      user_message = chat.messages.find_by(role: 'user')
      expect(user_message.attachments.count).to eq(2)
      expect(response.content).to be_present
    end

    it 'handles attachments in ask method' do
      chat = Chat.create!(model: model)

      image_upload = uploaded_file(image_path, 'image/png')

      response = chat.ask('What do you see?', with: image_upload)

      user_message = chat.messages.find_by(role: 'user')
      expect(user_message.attachments.count).to eq(1)
      expect(response.content).to be_present
    end

    describe 'attachment types' do
      it 'handles images' do
        chat = Chat.create!(model: model)
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

      it 'handles PDFs' do
        chat = Chat.create!(model: model)
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

  describe 'event callbacks' do
    it 'preserves user callbacks when using Rails integration' do
      user_callback_called = false
      end_callback_called = false

      chat = Chat.create!(model: model)

      # Set user callbacks before calling ask
      chat.on_new_message { user_callback_called = true }
      chat.on_end_message { end_callback_called = true }

      # Call ask which triggers to_llm and sets up persistence callbacks
      chat.ask('Hello')

      # Both user callbacks and persistence should work
      expect(user_callback_called).to be true
      expect(end_callback_called).to be true
      expect(chat.messages.count).to eq(2) # Persistence still works
    end

    it 'calls on_tool_call and on_tool_result callbacks' do
      tool_call_received = nil
      tool_result_received = nil

      chat = Chat.create!(model: model)
                 .with_tool(Calculator)
                 .on_tool_call { |tc| tool_call_received = tc }
                 .on_tool_result { |result| tool_result_received = result }

      chat.ask('What is 2 + 2?')

      expect(tool_call_received).not_to be_nil
      expect(tool_call_received.name).to eq('calculator')
      expect(tool_result_received).to eq('4')
    end
  end

  describe 'error recovery' do
    it 'does not clean up complete tool interactions when error occurs after tool execution' do
      chat = Chat.create!(model: model)
      chat.messages.create!(role: 'user', content: 'What is 5 + 5?')

      tool_call_msg = chat.messages.create!(role: 'assistant', content: nil)
      tool_call = tool_call_msg.tool_calls.create!(
        tool_call_id: 'call_123',
        name: 'calculator',
        arguments: { expression: '5 + 5' }.to_json
      )

      chat.messages.create!(
        role: 'tool',
        content: '10',
        parent_tool_call: tool_call
      )

      expect do
        chat.send(:cleanup_orphaned_tool_results)
      end.not_to(change { chat.messages.count })
    end

    it 'cleans up incomplete tool interactions with missing tool results' do
      chat = Chat.create!(model: model)

      chat.messages.create!(role: 'user', content: 'Do multiple calculations')

      tool_call_msg = chat.messages.create!(role: 'assistant', content: nil)
      tool_call1 = tool_call_msg.tool_calls.create!(
        tool_call_id: 'call_1',
        name: 'calculator',
        arguments: { expression: '2 + 2' }.to_json
      )
      tool_call_msg.tool_calls.create!(
        tool_call_id: 'call_2',
        name: 'calculator',
        arguments: { expression: '3 + 3' }.to_json
      )

      chat.messages.create!(
        role: 'tool',
        content: '4',
        parent_tool_call: tool_call1
      )

      chat.messages.count

      expect do
        chat.send(:cleanup_orphaned_tool_results)
      end.to change { chat.messages.count }.by(-2)
    end

    it 'cleans up orphaned tool call messages with no results' do
      chat = Chat.create!(model: model)

      chat.messages.create!(role: 'user', content: 'What is 3 + 3?')

      tool_call_msg = chat.messages.create!(role: 'assistant', content: nil)
      tool_call_msg.tool_calls.create!(
        tool_call_id: 'call_456',
        name: 'calculator',
        arguments: { expression: '3 + 3' }.to_json
      )

      expect do
        chat.send(:cleanup_orphaned_tool_results)
      end.to change { chat.messages.count }.by(-1)
    end
  end

  describe 'assume_model_exists' do
    it 'creates a Model record when assume_model_exists is true' do
      chat = Chat.new
      chat.assume_model_exists = true
      chat.model = 'my-custom-model'
      chat.provider = 'openrouter'
      chat.save!

      model = Model.find_by(model_id: 'my-custom-model', provider: 'openrouter')
      expect(model).not_to be_nil
      expect(model.model_id).to eq('my-custom-model')
      expect(model.provider).to eq('openrouter')
      expect(chat.model_id).to eq('my-custom-model')
      expect(chat.provider).to eq('openrouter')
    end

    it 'works with Chat.create! and assume_model_exists' do
      chat = Chat.create!(
        model: 'another-custom-model',
        provider: 'bedrock',
        assume_model_exists: true
      )

      model = Model.find_by(model_id: 'another-custom-model', provider: 'bedrock')
      expect(model).not_to be_nil
      expect(model.model_id).to eq('another-custom-model')
      expect(model.provider).to eq('bedrock')
      expect(chat.model_id).to eq('another-custom-model')
      expect(chat.provider).to eq('bedrock')
    end

    it 'uses existing models when available' do
      initial_count = Model.count

      # Create a known model first
      chat1 = Chat.create!(model: 'gpt-4.1-nano')

      # Should use existing model
      chat2 = Chat.create!(model: 'gpt-4.1-nano')

      # Count should not increase since model already exists
      expect(Model.count).to eq(initial_count)
      expect(chat1.model_id).to eq('gpt-4.1-nano')
      expect(chat2.model_id).to eq('gpt-4.1-nano')
      expect(chat1.model).to eq(chat2.model)
    end

    it 'respects aliases' do
      chat = Chat.create!(model: 'claude-3-5-sonnet', provider: 'bedrock')

      expect(chat.model_id).to eq('anthropic.claude-3-5-sonnet-20240620-v1:0:200k')
      expect(chat.provider).to eq('bedrock')
    end
  end
end
