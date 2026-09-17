# frozen_string_literal: true

require 'rails_helper'
require 'stringio'
require 'active_support/testing/time_helpers'
require_relative '../../support/query_helpers'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'
  include ActiveSupport::Testing::TimeHelpers

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.create_table :action_text_chats, force: true do |t|
        t.references :ruby_llm_model
        t.boolean :cancelled, null: false, default: false
        t.timestamps
      end

      ActiveRecord::Migration.create_table :action_text_messages, force: true do |t|
        t.references :action_text_chat
        t.string :role
        t.text :content
        t.json :content_raw
        t.boolean :cache_until_here, null: false, default: false
        t.string :model_id
        t.string :provider
        t.integer :input_tokens
        t.integer :output_tokens
        t.integer :cache_read_tokens
        t.integer :cache_write_tokens
        t.text :thinking_signature
        t.text :thinking_text
        t.integer :thinking_tokens
        t.timestamps
      end

      ActiveRecord::Migration.create_table :action_text_attachables, force: true do |t|
        t.string :label, null: false
        t.timestamps
      end
    end
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveRecord::Migration.suppress_messages do
      if ActiveRecord::Base.connection.table_exists?(:action_text_attachables)
        ActiveRecord::Migration.drop_table :action_text_attachables
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
                    chat_class: 'ActionTextChat'
    has_rich_text :content
    has_many_attached :attachments
  end

  class ActionTextAttachable < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    include ActionText::Attachable

    def attachable_plain_text_representation(caption)
      "[#{caption || label}]"
    end
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
    [1, 10].each do |message_count|
      it "loads rich text once for a transcript with #{message_count} #{'message'.pluralize(message_count)}" do
        message_count.times do |index|
          chat.action_text_messages.create!(role: :user, content: "<div>Message <strong>#{index}</strong></div>")
        end
        fresh_chat = ActionTextChat.find(chat.id)

        queries = QueryHelpers.matching(/action_text_rich_texts/i) do
          expect(fresh_chat.to_llm.messages.map(&:content)).to eq(
            Array.new(message_count) { |index| "Message #{index}" }
          )
        end

        expect(queries.size).to eq(1)
      end
    end

    context 'when the message model has rich text content' do
      it 'converts messages without rich text without querying blobs' do
        message = chat.action_text_messages.create!(role: :user)
        expect(message.rich_text_content).to be_nil
        fresh_chat = ActionTextChat.find(chat.id)
        converted = nil

        queries = QueryHelpers.matching(/active_storage_blobs/i) do
          converted = fresh_chat.to_llm.messages.first
        end

        expect(converted.content).to eq('')
        expect(converted.attachments).to be_empty
        expect(queries).to be_empty
      end

      it 'loads rich text content once for the whole transcript' do
        10.times do |index|
          chat.action_text_messages.create!(role: :user, content: "<div>Message #{index}</div>")
        end
        fresh_chat = ActionTextChat.find(chat.id)

        queries = QueryHelpers.matching(/action_text_rich_texts/i) { fresh_chat.to_llm }

        expect(queries.size).to eq(1)
      end

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
      it 'skips embed preloading for a transcript containing only non-blob nodes' do
        blob = create_blob(filename: 'expired.txt')
        expired_sgid = blob.to_sgid(expires_in: 1.minute, for: ActionText::Attachable::LOCATOR_NAME).to_s
        custom = ActionTextAttachable.create!(label: 'Card')
        bodies = [
          ActionText::Attachment.from_attributes(
            url: 'https://example.com/image.png', content_type: 'image/png'
          ).to_html,
          ActionText::Attachment.from_attributes(content: '<p>Inline</p>', content_type: 'text/html').to_html,
          ActionText::Attachment.from_attributes(sgid: 'invalid').to_html,
          ActionText::Attachment.from_attributes(sgid: expired_sgid).to_html,
          ActionText::Attachment.from_attachable(custom).to_html
        ]
        messages = bodies.map { |body| chat.action_text_messages.create!(role: :user, content: body) }

        travel 2.minutes do
          expected = messages.map { |message| message.content.to_plain_text }
          fresh_chat = ActionTextChat.find(chat.id)
          converted = nil
          queries = QueryHelpers.matching(/active_storage_attachments|active_storage_blobs/i) do
            converted = fresh_chat.to_llm.messages
          end

          expect(converted.map(&:content)).to eq(expected)
          expect(converted.flat_map(&:attachments)).to be_empty
          expect(queries.grep(/active_storage_blobs/i)).to be_empty
          expect(queries.grep(/active_storage_attachments/i).size).to eq(1)
        end
      end

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

        expect(llm_message.content).to eq('Rich text with attachment')
        expect(llm_message.attachments.first.mime_type).to eq('text/plain')
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
        expect(llm_message.content).to include('See file:')
        expect(llm_message.attachments.first.filename).to eq('embedded.txt')
        expect(llm_message.attachments.first.mime_type).to eq('text/plain')
        expect(llm_message.attachments.first.content).to eq('embedded file data')
      end

      it 'loads embedded Action Text blobs in one query for a transcript' do
        10.times do |index|
          blob = create_blob(content: "embedded file data #{index}", filename: "embedded-#{index}.txt")
          attachment = ActionText::Attachment.from_attachable(blob)
          chat.action_text_messages.create!(
            role: :user,
            content: "<div>See file #{index}:</div>#{attachment.to_html}"
          )
        end
        fresh_chat = ActionTextChat.find(chat.id)
        contents = nil

        queries = QueryHelpers.matching(/active_storage_blobs/i) do
          contents = fresh_chat.to_llm.messages.map(&:content)
        end

        expect(queries.size).to eq(1)
        expect(contents).to eq(Array.new(10) { |index| "See file #{index}:\n[embedded-#{index}.txt]" })
      end

      it 'renders Action Text attachments as Rails does' do
        blob = create_blob(content: 'embedded file data', filename: 'embedded.txt')
        remote_image = '<action-text-attachment url="https://example.com/remote.png" ' \
                       'content-type="image/png" filename="remote.png"></action-text-attachment>'
        content_attachment = '<action-text-attachment content="&lt;p&gt;inline&lt;/p&gt;" ' \
                             'content-type="text/html"></action-text-attachment>'
        messages = [
          "<div>Captioned: #{ActionText::Attachment.from_attachable(blob, caption: 'Vroom').to_html}</div>",
          "<div>Remote: #{remote_image}</div>",
          "<div>Inline: #{content_attachment}</div>",
          '<div>Gone: <action-text-attachment sgid="not-a-real-sgid"></action-text-attachment></div>',
          "<div>Mixed: #{content_attachment} and #{ActionText::Attachment.from_attachable(blob).to_html}</div>"
        ].map { |body| chat.action_text_messages.create!(role: :user, content: body) }

        messages.each do |message|
          expect(message.to_llm.content).to eq(message.content.to_plain_text)
          expect(message.to_llm.content).to be_present
        end
      end

      it 'preserves custom Action Text attachables' do
        attachable = ActionTextAttachable.create!(label: 'Card')
        attachment = ActionText::Attachment.from_attachable(attachable)
        message = chat.action_text_messages.create!(
          role: :user,
          content: "<div>See card:</div>#{attachment.to_html}"
        )

        llm_message = message.to_llm

        expect(llm_message.content).to include('See card:')
        expect(llm_message.content).to include('[Card]')
        expect(llm_message.attachments).to be_empty
      end

      it 'renders fallback content with an invalid SGID as Rails does' do
        attachment = ActionText::Attachment.from_attributes(
          sgid: 'invalid', content_type: 'text/html', content: '<p>safe</p><script>unsafe()</script>'
        )
        message = chat.action_text_messages.create!(role: :user, content: attachment.to_html)

        expect(message.to_llm.content).to eq(message.content.to_plain_text)
      end

      [nil, 'invalid'].each do |sgid|
        it "handles inline content sanitized to empty with #{sgid ? 'an invalid' : 'no'} SGID" do
          attachment = ActionText::Attachment.from_attributes(
            sgid: sgid, content_type: 'text/html', content: '<iframe></iframe>'
          )
          message = chat.action_text_messages.create!(role: :user, content: attachment.to_html)

          converted = message.to_llm

          expect(converted.content).to eq(message.content.to_plain_text)
          expect(converted.content).to eq('')
          expect(converted.attachments).to be_empty
        end
      end

      it 'resolves embedded blobs when only the attachment records are preloaded' do
        blob = create_blob(content: 'embedded payload', filename: 'embedded.txt')
        attachment = ActionText::Attachment.from_attachable(blob)
        message = chat.action_text_messages.create!(role: :user, content: attachment.to_html).reload
        rich_text = message.content
        ActiveRecord::Associations::Preloader.new(records: [rich_text], associations: :embeds_attachments).call
        expect(rich_text.embeds_attachments).not_to be_empty
        expect(rich_text.embeds_attachments.map { |embed| embed.association(:blob).loaded? }).to all(be(false))

        converted = message.to_llm

        expect(converted.content).to eq('[embedded.txt]')
        expect(converted.attachments.size).to eq(1)
        expect(converted.attachments.first.content).to eq('embedded payload')
      end

      it 'revalidates expiring SGIDs on subsequent conversions' do
        blob = create_blob(filename: 'expiring.txt')
        sgid = blob.to_sgid(expires_in: 1.minute, for: ActionText::Attachable::LOCATOR_NAME).to_s
        attachment = ActionText::Attachment.from_attributes(sgid: sgid)
        message = chat.action_text_messages.create!(role: :user, content: attachment.to_html)
        expect(message.to_llm.content).to eq('[expiring.txt]')

        travel 2.minutes do
          converted = message.to_llm
          expect(converted.content).to eq(message.content.to_plain_text)
          expect(converted.attachments).to be_empty
        end
      end

      it 'reflects custom attachable edits on subsequent conversions' do
        attachable = ActionTextAttachable.create!(label: 'Before')
        attachment = ActionText::Attachment.from_attachable(attachable)
        message = chat.action_text_messages.create!(role: :user, content: attachment.to_html)
        expect(message.to_llm.content).to eq('[Before]')
        attachable.update!(label: 'After')

        expect(message.to_llm.content).to eq('[After]')
      end
    end
  end
end
