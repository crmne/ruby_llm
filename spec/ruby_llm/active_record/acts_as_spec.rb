# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs, :live do
  let(:model) { 'gpt-4.1-nano' }

  def usage_tracker(provider, recorder, config: RubyLLM.config)
    RubyLLM.const_get(:Usage)::Tracker.new(
      operation: :chat,
      provider: provider,
      model: RubyLLM.models.find(model),
      config:,
      on_finish: recorder
    )
  end

  it 'exposes only the application-owned chat and message macros' do
    expect(ActiveRecord::Base).to respond_to(:acts_as_chat, :acts_as_message)
    expect(ActiveRecord::Base).not_to respond_to(:acts_as_model, :acts_as_tool_call, :acts_as_batch)
  end

  describe 'basic chat functionality' do
    it 'persists generic add_message calls' do
      chat = Chat.create!(model: model)
      message = chat.add_message(role: :system, content: 'Be concise')

      expect(message.role).to eq('system')
      expect(chat.messages.pluck(:content)).to eq(['Be concise'])
    end

    it 'persists chat history' do
      chat = Chat.create!(model: model)
      chat.ask("What's your favorite Ruby feature?")

      expect(chat.messages.pluck(:role)).to eq(%w[user assistant])
      expect(chat.messages.last.content).to be_present
    end

    it 'belongs to RubyLLM\'s internal model record' do
      chat = Chat.create!(model: model)

      expect(chat.model).to be_a(RubyLLM::ActiveRecord::Model)
      expect(chat.model.model_id).to eq(model)
      expect(chat.model_id).to eq(model)
      expect(chat.provider).to eq('openai')
      expect(Chat.reflect_on_association(:model).class_name).to eq('RubyLLM::ActiveRecord::Model')
      expect(Chat.reflect_on_association(:model).foreign_key).to eq('ruby_llm_model_id')
    end
  end

  describe 'usage persistence' do
    it 'persists attempts independently and links them to the resulting message' do
      chat = Chat.create!(model: model)
      provider = chat.to_llm.provider

      allow(provider).to receive(:complete) do |_messages, usage_recorder:, **|
        tracker = usage_tracker(provider, usage_recorder)
        failed = tracker.start
        tracker.fail_attempt(failed, RubyLLM::ServerError.new('retry'))
        tracker.start
        response = RubyLLM::Message.new(
          role: :assistant, content: 'Hello', model:, input_tokens: 8, output_tokens: 3
        )
        tracker.succeed(response)
      end

      chat.ask('Hello')

      records = chat.reload.ruby_llm_usages.includes(:message)
      expect(records.map(&:status)).to eq(%w[failed succeeded])
      expect(records.map(&:message)).to all(eq(chat.messages.last))
      expect(chat.messages.last.tokens.to_h).to eq(input_tokens: 8, output_tokens: 3)
      expect(chat.tokens.to_h).to eq(input_tokens: 8, output_tokens: 3)
      expect(chat).not_to respond_to(:usage)
      expect(chat.messages.last).not_to respond_to(:usage)
    end

    it 'persists each attempt before publishing its usage event' do
      observed_counts = []
      chat = Chat.create!(model: model)
      instrumenter_class = Class.new do
        def initialize(&callback)
          @callback = callback
        end

        def instrument(name, payload, &block)
          result = block&.call
          @callback.call(payload) if name == 'usage.ruby_llm'
          result
        end
      end
      instrumenter = instrumenter_class.new { observed_counts << chat.ruby_llm_usages.count }
      context = RubyLLM.context { |config| config.instrumenter = instrumenter }
      chat.with_context(context)
      provider = chat.to_llm.provider

      allow(provider).to receive(:complete) do |_messages, usage_recorder:, **|
        tracker = usage_tracker(provider, usage_recorder, config: context.config)
        failed = tracker.start
        tracker.fail_attempt(failed, RubyLLM::ServerError.new('retry'))
        tracker.start
        tracker.succeed(RubyLLM::Message.new(role: :assistant, content: 'Hello', model:))
      end

      chat.ask('Hello')

      expect(observed_counts).to eq([1, 2])
    end

    it 'persists a batch response as one usage attempt' do
      chat = Chat.create!(model: model).ask_later('Hello')
      llm_chat = chat.to_llm
      provider = llm_chat.provider
      response = RubyLLM::Message.new(
        role: :assistant, content: 'Hello', model:, input_tokens: 8, output_tokens: 3
      )
      allow(provider).to receive(:batch_results).and_return([[0, response]])
      batch = RubyLLM::Batch.new(
        provider:, chats: [llm_chat], id: 'batch_test', raw_status: 'completed', completed: true
      )

      batch.messages

      usage = chat.reload.ruby_llm_usages.sole
      expect(usage).to have_attributes(status: 'succeeded', message: chat.messages.last)
      expect(usage.tokens.to_h).to eq(input_tokens: 8, output_tokens: 3)
      expect(chat.cost.total).to eq(usage.cost.total)
    end

    it 'reloads linked and unlinked entries chronologically' do
      chat = Chat.create!(model: model)
      message = chat.messages.create!(role: :assistant, content: 'done', model_id: model, provider: 'openai')
      first = chat.ruby_llm_usages.create!(
        message:, operation: 'chat', provider: 'openai', model:, status: 'succeeded',
        input_tokens: 4, output_tokens: 2
      )
      orphan = chat.ruby_llm_usages.create!(
        operation: 'chat', provider: 'openai', model:, status: 'cancelled'
      )

      llm_chat = chat.reload.to_llm
      entries = llm_chat.usage_entries
      message_entries = llm_chat.messages.sole.ruby_llm_usage_entries

      expect(entries.map(&:status)).to eq(%i[succeeded cancelled])
      expect(message_entries.sole).to equal(entries.first)
      expect(chat.ruby_llm_usages.pluck(:id)).to eq([first.id, orphan.id])
    end

    it 'keeps usage when a cancelled stream produces no message' do
      stub_const('RubyLLM::ActiveRecord::ChatMethods::CANCELLATION_POLL_INTERVAL', 0.0)
      chat = Chat.create!(model: model).ask_later('Hello')
      provider = chat.to_llm.provider

      allow(provider).to receive(:complete) do |_messages, usage_recorder:, **_kwargs, &block|
        tracker = usage_tracker(provider, usage_recorder)
        entry = tracker.start
        begin
          chunk = RubyLLM::Chunk.new(role: :assistant, content: 'one', input_tokens: 5, output_tokens: 1)
          tracker.observe(chunk)
          block.call(chunk)
          Chat.find(chat.id).cancel
          block.call(RubyLLM::Chunk.new(role: :assistant, content: 'two'))
        rescue StandardError => e
          tracker.fail_attempt(entry, e)
          raise
        end
      end

      expect { chat.complete { |chunk| chunk } }.to raise_error(RubyLLM::CancelledError)

      entry = chat.reload.ruby_llm_usages.sole
      expect(entry.status).to eq('cancelled')
      expect(entry.tokens.output).to eq(1)
      expect(entry.message).to be_nil
      expect(chat.messages.pluck(:role)).to eq(['user'])
    end

    it 'uses normalized cost columns rather than a JSON cost payload' do
      columns = RubyLLM::ActiveRecord::Usage.column_names

      expect(columns).to include('input_cost', 'output_cost', 'cache_read_cost', 'cache_write_cost',
                                 'thinking_cost', 'total_cost')
      expect(columns).not_to include('cost_details', 'finish_reason', 'usage_status')
    end

    it 'does not reprice a persisted entry whose cost was unavailable' do
      chat = Chat.create!(model: model)
      record = chat.ruby_llm_usages.create!(
        operation: 'chat', provider: 'openai', model:, status: 'succeeded',
        input_tokens: 10
      )

      expect(record.cost.input).to be_nil
      expect(record.cost.total).to be_nil
    end
  end

  describe 'tool-call persistence' do
    it 'returns public values while RubyLLM owns the rows' do
      chat = Chat.create!(model: model)
      assistant = chat.messages.create!(role: :assistant, content: '')
      record = assistant.ruby_llm_tool_calls.create!(
        tool_call_id: 'call_1', name: 'weather', arguments: { city: 'Berlin' }
      )
      result = chat.messages.create!(role: :tool, content: 'sunny')
      record.update!(result:)

      expect(assistant.tool_calls.fetch('call_1')).to be_a(RubyLLM::ToolCall)
      expect(result.parent_tool_call.to_h).to include(id: 'call_1', name: 'weather')
      expect(assistant.tool_results).to eq([result])
    end

    it 'removes internal tool and usage rows when their chat is destroyed' do
      chat = Chat.create!(model: model)
      message = chat.messages.create!(role: :assistant, content: '')
      message.ruby_llm_tool_calls.create!(tool_call_id: 'call_destroy', name: 'noop', arguments: {})
      chat.ruby_llm_usages.create!(
        message:, operation: 'chat', provider: 'openai', model:, status: 'succeeded'
      )

      expect { chat.destroy! }
        .to change(RubyLLM::ActiveRecord::ToolCall, :count).by(-1)
        .and change(RubyLLM::ActiveRecord::Usage, :count).by(-1)
    end
  end

  describe 'custom application model names' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :support_conversations, force: true do |t|
          t.references :ruby_llm_model
          t.boolean :cancelled, null: false, default: false
          t.timestamps
        end
        ActiveRecord::Migration.create_table :support_messages, force: true do |t|
          t.references :conversation
          t.string :role
          t.text :content
          t.boolean :cache_until_here, null: false, default: false
          t.timestamps
        end
      end
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.drop_table :support_messages, if_exists: true
        ActiveRecord::Migration.drop_table :support_conversations, if_exists: true
      end
    end

    # rubocop:disable-next Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
    module Support
      class Conversation < ActiveRecord::Base
        self.table_name = 'support_conversations'
        acts_as_chat messages: :support_messages, message_class: 'Support::Message',
                     messages_foreign_key: :conversation_id
      end

      class Message < ActiveRecord::Base
        self.table_name = 'support_messages'
        acts_as_message chat: :conversation, chat_class: 'Support::Conversation',
                        chat_foreign_key: :conversation_id
      end
    end

    it 'uses polymorphic internal rows without extra application models' do
      chat = Support::Conversation.create!(model: model)
      message = chat.support_messages.create!(role: :assistant, content: 'done')
      chat.ruby_llm_usages.create!(
        message:, operation: 'chat', provider: 'openai', model:, status: 'succeeded'
      )

      expect(chat.ruby_llm_usages.sole.message).to eq(message)
      expect(message.ruby_llm_usages.sole.model).to eq(model)
    end

    it 'persists completions without accounting columns on messages' do
      chat = Support::Conversation.create!(model: model)
      provider = chat.to_llm.provider
      allow(provider).to receive(:complete) do |_messages, usage_recorder:, **|
        tracker = usage_tracker(provider, usage_recorder)
        tracker.start
        tracker.succeed(
          RubyLLM::Message.new(role: :assistant, content: 'lean', model:, input_tokens: 3, output_tokens: 1)
        )
      end

      response = chat.ask('Hello')
      message = chat.support_messages.last

      expect(response.content).to eq('lean')
      expect(message.content).to eq('lean')
      expect(message.tokens.input).to eq(3)
      expect(message.cost.total).to be_a(Numeric)
      expect(message.attributes).not_to include('input_tokens', 'model_id', 'provider')
    end
  end
end
