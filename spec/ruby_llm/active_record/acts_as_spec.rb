# frozen_string_literal: true

require 'spec_helper'
require 'active_record'
require 'ruby_llm/active_record/acts_as'
require 'tmpdir'

# Custom adapter for testing URL transformations
class CustomAdapter
  def self.transform_base64_to_url(_base64_data)
    # Simulate a URL transformation - in a real app, this might save to a storage service
    "https://example.com/#{SecureRandom.hex(8)}"
  end
end

# URL adapter for testing - transforms base64 data to URLs
def create_url_adapter # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
  lambda do |operation, part, record: nil| # rubocop:disable Lint/UnusedBlockArgument
    case operation
    when :store
      if part[:type] == 'image' && part[:source].is_a?(Hash) && part[:source][:type] == 'base64'
        {
          type: part[:type],
          source: {
            url: CustomAdapter.transform_base64_to_url(part[:source][:data])
          }
        }
      elsif part[:type] == 'pdf' && part[:source].is_a?(Hash) && part[:source][:data].present?
        {
          type: part[:type],
          source: {
            url: CustomAdapter.transform_base64_to_url(part[:source][:data]),
            media_type: 'application/pdf'
          }
        }
      else
        part
      end
    when :retrieve
      part
    end
  end
end

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

  describe 'rich attachments' do
    # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations

    let(:test_image_path) { File.join(File.dirname(__FILE__), '../../fixtures/ruby.png') }
    let(:test_pdf_path) { File.join(File.dirname(__FILE__), '../../fixtures/sample.pdf') }

    # Read base64 data from fixture files
    let(:base64_image) { Base64.strict_encode64(File.binread(test_image_path)) }
    let(:base64_pdf) { Base64.strict_encode64(File.binread(test_pdf_path)) }

    # Stub the complete method to avoid making actual API calls
    before do
      allow_any_instance_of(RubyLLM::Chat).to receive(:complete).and_return(nil) # rubocop:disable RSpec/AnyInstance

      allow(RubyLLM::Content).to receive(:new).and_wrap_original do |original_method, *args|
        if args.length > 1 && args[1].is_a?(Hash)
          text = args[0]
          attachments = args[1]

          content = original_method.call(text)

          if attachments[:image]
            Array(attachments[:image]).each do |_|
              content.instance_variable_get(:@parts) << {
                type: 'image',
                source: {
                  type: 'base64',
                  data: base64_image,
                  media_type: 'image/png'
                }
              }
            end
          end

          if attachments[:pdf]
            Array(attachments[:pdf]).each do |_|
              content.instance_variable_get(:@parts) << {
                type: 'pdf',
                source: {
                  data: base64_pdf
                }
              }
            end
          end

          content
        else
          original_method.call(*args)
        end
      end
    end

    it 'supports asking with a single image attachment' do
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      chat.ask("What's in this image?", with: { image: test_image_path })

      user_message = chat.messages.where(role: 'user').first
      expect(user_message.content).to be_a(RubyLLM::Content)

      # Verify the content has been properly created with parts
      content_parts = user_message.extract_content.to_a
      expect(content_parts.size).to eq(2)
      expect(content_parts.first[:type]).to eq('text')
      expect(content_parts.first[:text]).to eq("What's in this image?")
      expect(content_parts.last[:type]).to eq('image')
    end

    it 'supports asking with a PDF attachment' do
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      chat.ask('Analyze this document', with: { pdf: test_pdf_path })

      user_message = chat.messages.where(role: 'user').first
      expect(user_message.content).to be_a(RubyLLM::Content)

      content_parts = user_message.extract_content.to_a
      expect(content_parts.size).to eq(2)
      expect(content_parts.first[:type]).to eq('text')
      expect(content_parts.last[:type]).to eq('pdf')
    end

    it 'supports asking with multiple attachments' do
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      chat.ask('Analyze these files', with: {
                 image: test_image_path,
                 pdf: test_pdf_path
               })

      user_message = chat.messages.where(role: 'user').first
      expect(user_message.content).to be_a(RubyLLM::Content)

      content_parts = user_message.extract_content.to_a
      expect(content_parts.size).to eq(3) # Text + image + pdf
      expect(content_parts.first[:type]).to eq('text')

      # Check that we have both image and pdf attachments
      attachment_types = content_parts.map { |part| part[:type] }
      expect(attachment_types).to include('image')
      expect(attachment_types).to include('pdf')
    end

    it 'supports asking with multiple images' do
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      chat.ask('Compare these images', with: {
                 image: [test_image_path, test_image_path]
               })

      user_message = chat.messages.where(role: 'user').first
      expect(user_message.content).to be_a(RubyLLM::Content)

      content_parts = user_message.extract_content.to_a
      expect(content_parts.size).to eq(3) # Text + 2 images

      # Count the number of image parts
      image_parts = content_parts.select { |part| part[:type] == 'image' }
      expect(image_parts.size).to eq(2)
    end

    it 'properly persists content with attachments' do
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      chat.ask("What's in this image?", with: { image: test_image_path })

      chat.reload
      user_message = chat.messages.where(role: 'user').first

      # When loaded from the database, the content should be properly deserialized
      expect(user_message.content).to be_a(RubyLLM::Content)
      expect(user_message.extract_content).to be_a(RubyLLM::Content)

      content_parts = user_message.extract_content.to_a
      expect(content_parts).not_to be_nil
      expect(content_parts.first[:type]).to eq('text')
    end

    it 'supports custom adapter that transforms base64 to URLs' do
      message = Message.new(role: 'user')

      # Create a Content object with an image
      content = RubyLLM::Content.new('This is a message with an image')
      content.instance_variable_set(:@parts, [
                                      { type: 'text', text: 'This is a message with an image' },
                                      { type: 'image',
                                        source: { type: 'base64', data: base64_image, media_type: 'image/png' } }
                                    ])

      # Temporarily override the storage adapter for this test
      original_adapter = Message.instance_variable_get(:@attachment_storage)
      Message.instance_variable_set(:@attachment_storage, create_url_adapter)

      begin
        message.content = content
        expect(message.save).to be true
        message.reload

        expect(message.content).to be_a(RubyLLM::Content)

        parts = message.content.to_a
        expect(parts.length).to eq(2)
        expect(parts[0][:type]).to eq('text')
        expect(parts[0][:text]).to eq('This is a message with an image')
        expect(parts[1][:type]).to eq('image')

        source = parts[1][:source]
        expect(source.key?('url') || source.key?(:url)).to be true
        url = source['url'] || source[:url]
        expect(url).to start_with('https://example.com/')
        expect(source['data'] || source[:data]).to be_nil
      ensure
        # Restore the original adapter
        Message.instance_variable_set(:@attachment_storage, original_adapter)
      end
    end
  end
  # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations

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

    it 'persists system messages' do # rubocop:disable RSpec/MultipleExpectations
      chat = Chat.create!(model_id: 'gpt-4o-mini')
      chat.with_instructions('You are a Ruby expert')

      expect(chat.messages.first.role).to eq('system')
      expect(chat.messages.first.content).to eq('You are a Ruby expert')
    end

    it 'optionally replaces existing system messages' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      chat = Chat.create!(model_id: 'gpt-4o-mini')

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
end
