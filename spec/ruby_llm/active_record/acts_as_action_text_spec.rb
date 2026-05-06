# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.create_table :action_text_chats, force: true do |t|
        t.references :model
        t.timestamps
      end

      ActiveRecord::Migration.create_table :action_text_messages, force: true do |t|
        t.references :action_text_chat
        t.string :role
        t.text :content
        t.json :content_raw
        t.references :model
        t.integer :input_tokens
        t.integer :output_tokens
        t.integer :cached_tokens
        t.integer :cache_creation_tokens
        t.text :thinking_signature
        t.text :thinking_text
        t.integer :thinking_tokens
        t.references :action_text_tool_call
        t.timestamps
      end

      ActiveRecord::Migration.create_table :action_text_tool_calls, force: true do |t|
        t.references :action_text_message
        t.string :tool_call_id
        t.string :name
        t.text :thought_signature
        t.json :arguments
        t.timestamps
      end
    end
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveRecord::Migration.suppress_messages do
      if ActiveRecord::Base.connection.table_exists?(:action_text_tool_calls)
        ActiveRecord::Migration.drop_table :action_text_tool_calls
      end
      if ActiveRecord::Base.connection.table_exists?(:action_text_messages)
        ActiveRecord::Migration.drop_table :action_text_messages
      end
      if ActiveRecord::Base.connection.table_exists?(:action_text_chats)
        ActiveRecord::Migration.drop_table :action_text_chats
      end
    end
  end

  class ActionTextChat < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    acts_as_chat messages: :action_text_messages, message_class: 'ActionTextMessage'
  end

  class ActionTextMessage < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    acts_as_message chat: :action_text_chat,
                    chat_class: 'ActionTextChat',
                    tool_calls: :action_text_tool_calls,
                    tool_call_class: 'ActionTextToolCall'
    has_rich_text :content
    has_many_attached :attachments
  end

  class ActionTextToolCall < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    acts_as_tool_call message: :action_text_message, message_class: 'ActionTextMessage'
  end

  let(:chat) { ActionTextChat.create! }

  def create_blob(content: 'test data', filename: 'test.txt', content_type: 'text/plain')
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename: filename,
      content_type: content_type
    )
  end

  describe 'Action Text content extraction' do
    context 'when the message model has rich text content' do
      it 'extracts plain text from Action Text content' do
        message = chat.action_text_messages.create!(
          role: :user,
          content: '<div>This is <strong>plain</strong> text</div>'
        )

        llm_message = message.to_llm

        expect(message.content).to be_a(ActionText::RichText)
        expect(message[:content]).to be_nil
        expect(llm_message.content).to eq('This is plain text')
      end
    end

    context 'when the message model uses a regular text column' do
      it 'returns content unchanged' do
        message = Chat.create!.messages.create!(role: :user, content: 'Regular text content')

        expect(message.content).to eq('Regular text content')
        expect(message.to_llm.content).to eq('Regular text content')
      end
    end

    context 'when the rich text message has Active Storage attachments' do
      it 'combines Action Text content with model attachments into RubyLLM::Content' do
        message = chat.action_text_messages.create!(
          role: :user,
          content: '<div>Rich text with attachment</div>'
        )
        message.attachments.attach(
          io: StringIO.new('test data'),
          filename: 'test.txt',
          content_type: 'text/plain'
        )

        llm_message = message.to_llm

        expect(llm_message.content).to be_a(RubyLLM::Content)
        expect(llm_message.content.text).to eq('Rich text with attachment')
        expect(llm_message.content.attachments.first.mime_type).to eq('text/plain')
      end

      it 'extracts embedded Action Text attachments into RubyLLM::Content' do
        blob = create_blob(content: 'embedded file data', filename: 'embedded.txt')
        attachment = ActionText::Attachment.from_attachable(blob)
        message = chat.action_text_messages.create!(
          role: :user,
          content: "<div>See file:</div>#{attachment.to_html}"
        )

        llm_message = message.to_llm

        expect(message.content.body.attachables).to include(blob)
        expect(llm_message.content).to be_a(RubyLLM::Content)
        expect(llm_message.content.text).to include('See file:')
        expect(llm_message.content.attachments.first.filename).to eq('embedded.txt')
        expect(llm_message.content.attachments.first.mime_type).to eq('text/plain')
        expect(llm_message.content.attachments.first.content).to eq('embedded file data')
      end
    end
  end
end
