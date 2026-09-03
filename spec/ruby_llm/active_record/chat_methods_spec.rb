# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:model_id) { 'gpt-4.1-nano' }

  def tool_call(id: "call_#{SecureRandom.hex(4)}", name: 'lookup', arguments: {})
    RubyLLM::ToolCall.new(id: id, name: name, arguments: arguments)
  end

  describe '#cancel' do
    it 'persists the request on a saved record' do
      chat = Chat.create!(model: model_id)

      chat.cancel

      expect(chat).to be_cancelled
      expect(Chat.find(chat.id)[:cancelled]).to be(true)
    end

    it 'holds the request in memory for an unsaved record' do
      chat = Chat.new(model: model_id)

      expect(chat.cancel).to eq(chat)
      expect(chat).to be_cancelled
      expect(chat).not_to be_persisted
    end

    it 'forwards the request to a chat that is already built' do
      chat = Chat.create!(model: model_id)
      chat.to_llm

      chat.cancel

      expect(chat.to_llm).to be_cancelled
    end
  end

  describe 'cancellation requests from another process' do
    it 'consumes a request written straight to the row' do
      chat = Chat.create!(model: model_id)
      chat[:cancelled] = true

      expect(chat.send(:consume_persisted_cancellation_request)).to eq(:cancelled)
      expect(chat[:cancelled]).to be(false)
      expect(Chat.find(chat.id)[:cancelled]).to be(false)
    end

    it 'polls the row at most once per interval' do
      chat = Chat.create!(model: model_id)

      expect(chat.send(:consume_persisted_cancellation_request)).to be_nil
      Chat.where(id: chat.id).update_all(cancelled: true)
      expect(chat.send(:consume_persisted_cancellation_request)).to be_nil
    end

    it 'notices a request another process wrote once the interval elapses' do
      chat = Chat.create!(model: model_id)
      Chat.where(id: chat.id).update_all(cancelled: true)

      expect(chat.send(:consume_persisted_cancellation_request)).to eq(:cancelled)
    end

    it 'sees a request another connection writes while the query cache is on' do
      chat = Chat.create!(model: model_id)

      Chat.cache do
        Chat.where(id: chat.id).pick(:cancelled)
        Thread.new { Chat.where(id: chat.id).update_all(cancelled: true) }.join

        expect(chat.send(:consume_persisted_cancellation_request)).to eq(:cancelled)
      end
    end

    it 'ignores an unsaved record' do
      expect(Chat.new(model: model_id).send(:consume_persisted_cancellation_request)).to be_nil
    end

    it 'clears an in-memory request without touching the database' do
      chat = Chat.new(model: model_id)
      chat[:cancelled] = true

      chat.send(:clear_cancellation_request)

      expect(chat[:cancelled]).to be(false)
    end
  end

  describe 'model assignment' do
    it 'fills an empty model store with the registry before adding the first chat' do
      allow(RubyLLM::ActiveRecord::Model).to receive(:none?).and_return(true)
      allow(RubyLLM::ActiveRecord::Model).to receive(:save_to_database).and_call_original

      Chat.create!(model: model_id)

      expect(RubyLLM::ActiveRecord::Model).to have_received(:save_to_database).with(RubyLLM.models)
    end

    it 'accepts a RubyLLM::Model value' do
      chat = Chat.new
      chat.model = RubyLLM.models.find(model_id)

      expect(chat.model_id).to eq(model_id)
      expect(chat.provider).to eq('openai')
    end

    it 'accepts a bare id through model_id=' do
      chat = Chat.new
      chat.model_id = model_id

      expect(chat.model_id).to eq(model_id)
      expect(chat.provider).to be_nil

      chat.save!
      expect(chat.model).to be_a(RubyLLM::ActiveRecord::Model)
    end

    it 'switches models with #with_model' do
      chat = Chat.create!(model: model_id)

      chat.with_model('gpt-4o-mini', provider: 'openai')

      expect(chat.model_id).to eq('gpt-4o-mini')
      expect(chat.reload.model_id).to eq('gpt-4o-mini')
      expect(chat.to_llm.model.id).to eq('gpt-4o-mini')
    end

    it 'falls back to the configured default model' do
      chat = Chat.create!(model: model_id)

      chat.with_model(nil)

      expect(chat.model_id).to eq(RubyLLM.config.default_model)
    end

    it 'accepts an unregistered id when told the model exists' do
      chat = Chat.create!(model: model_id)

      chat.with_model('made-up-deployment', provider: 'openai', assume_model_exists: true)

      expect(chat.model_id).to eq('made-up-deployment')
    end

    it 'reuses a model row another process inserted after the lookup missed' do
      relation = RubyLLM::ActiveRecord::Model.all
      allow(RubyLLM::ActiveRecord::Model).to receive(:all).and_return(relation)
      misses = 0
      allow(relation).to receive(:find_by).and_wrap_original do |original, *args|
        if args.first == { model_id: model_id, provider: 'openai' } && (misses += 1) == 1
          nil
        else
          original.call(*args)
        end
      end

      chat = Chat.create!(model: model_id)

      expect(chat.model_id).to eq(model_id)
      expect(RubyLLM::ActiveRecord::Model.where(model_id: model_id, provider: 'openai').count).to eq(1)
    end

    it 'requires a provider when assuming the model exists' do
      chat = Chat.new(model: model_id)
      chat.assume_model_exists = true
      chat.model_id = 'made-up-deployment'

      expect { chat.save! }.to raise_error(
        ArgumentError, 'Provider must be specified if assume_model_exists is true'
      )
    end
  end

  describe '#with_context' do
    it 'rebinds the record and any built chat' do
      chat = Chat.create!(model: model_id)
      chat.to_llm
      context = RubyLLM.context { |config| config.request_timeout = 42 }

      expect(chat.with_context(context)).to eq(chat)
      expect(chat.context).to eq(context)
      expect(chat.to_llm.provider.config.request_timeout).to eq(42)
    end
  end

  describe '#with_instructions' do
    it 'replaces the persisted system message by default' do
      chat = Chat.create!(model: model_id)

      chat.with_instructions('Be concise')
      chat.with_instructions('Be terse')

      expect(chat.messages.where(role: 'system').pluck(:content)).to eq(['Be terse'])
    end

    it 'keeps the system row in place ahead of the conversation' do
      chat = Chat.create!(model: model_id)
      chat.with_instructions('Be concise')
      system_id = chat.messages.find_by(role: 'system').id
      chat.add_message(role: :user, content: 'Hello')

      chat.with_instructions('Be concise')
      chat.with_instructions('Be terse')

      expect(chat.messages.find_by(role: 'system').id).to eq(system_id)
      expect(chat.messages.pluck(:role, :content)).to eq([['system', 'Be terse'], %w[user Hello]])
    end

    it 'appends when asked' do
      chat = Chat.create!(model: model_id)

      chat.with_instructions('Be concise')
      chat.with_instructions('Cite sources', append: true)

      expect(chat.messages.where(role: 'system').pluck(:content)).to eq(['Be concise', 'Cite sources'])
    end

    it 'does not duplicate an appended instruction on a chat not yet built' do
      chat = Chat.create!(model: model_id)
      chat.with_instructions('Be concise')

      reloaded = Chat.find(chat.id)
      reloaded.with_instructions('Cite sources', append: true)

      expect(reloaded.to_llm.messages.map(&:content)).to eq(['Be concise', 'Cite sources'])
    end

    it 'clears the persisted system messages when given nil' do
      chat = Chat.create!(model: model_id)
      chat.with_instructions('Be concise')

      chat.with_instructions(nil)

      expect(chat.messages.where(role: 'system')).to be_empty
      expect(chat.to_llm.messages).to be_empty
    end
  end

  describe '#with_instructions with persistence disabled' do
    it 'applies instructions without persisting them' do
      chat = Chat.create!(model: model_id)

      chat.with_instructions('Answer in French', persist: false)

      expect(chat.messages.where(role: 'system')).to be_empty
      expect(chat.to_llm.messages.map(&:content)).to eq(['Answer in French'])
    end

    it 'appends runtime instructions' do
      chat = Chat.create!(model: model_id)

      chat.with_instructions('Answer in French', persist: false)
      chat.with_instructions('Be brief', append: true, persist: false)

      expect(chat.to_llm.messages.map(&:content)).to eq(['Answer in French', 'Be brief'])
    end

    it 'survives a reload' do
      chat = Chat.create!(model: model_id)
      chat.with_instructions('Answer in French', persist: false)

      chat.reload

      expect(chat.to_llm.messages.map(&:content)).to eq(['Answer in French'])
    end

    it 'appends to persisted instructions and keeps them through a reload' do
      chat = Chat.create!(model: model_id)
      chat.with_instructions('Be concise')
      chat.with_instructions('Answer in French', append: true, persist: false)

      expect(chat.to_llm.messages.map(&:content)).to eq(['Be concise', 'Answer in French'])

      chat.reload

      expect(chat.to_llm.messages.map(&:content)).to eq(['Be concise', 'Answer in French'])
    end

    it 'keeps a runtime cache boundary through a reload' do
      chat = Chat.create!(model: model_id)
      chat.with_instructions('Persisted history')
      chat.with_instructions('Stable policy', persist: false, cache_until_here: true)
      chat.with_instructions('Current context', append: true, persist: false)

      expect(chat.to_llm.messages.map(&:cache_until_here?)).to eq([true, false])
      expect(chat.messages.where(cache_until_here: true)).to be_empty

      chat.reload

      expect(chat.to_llm.messages.map(&:content)).to eq(['Stable policy', 'Current context'])
      expect(chat.to_llm.messages.map(&:cache_until_here?)).to eq([true, false])
    end

    it 'drops them when given nil' do
      chat = Chat.create!(model: model_id)
      chat.with_instructions('Answer in French', persist: false)

      expect(chat.with_instructions(nil, persist: false)).to eq(chat)
      expect(chat.to_llm.messages).to be_empty
    end
  end

  describe '#with_instructions with a cache boundary' do
    it 'persists the boundary with persisted instructions' do
      chat = Chat.create!(model: model_id)

      chat.with_instructions('Stable policy', cache_until_here: true)

      expect(chat.messages.where(role: 'system').sole.cache_until_here?).to be(true)
      expect(chat.to_llm.messages.sole.cache_until_here?).to be(true)
    end
  end

  describe '#add_message' do
    it 'links a tool result to the tool call that produced it' do
      call = tool_call
      chat = Chat.create!(model: model_id)
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))

      result = chat.add_message(RubyLLM::Message.new(role: :tool, content: 'done', tool_call_id: call.id))

      expect(RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call.id).result).to eq(result)
    end
  end

  describe '#cache_until_here' do
    it 'marks the last persisted message' do
      chat = Chat.create!(model: model_id)
      chat.add_message(role: :user, content: 'Reusable prompt')

      chat.cache_until_here

      expect(chat.messages.last.cache_until_here?).to be(true)
    end

    it 'marks the last in-memory message when nothing is persisted' do
      chat = Chat.create!(model: model_id)
      chat.to_llm.add_message(role: :user, content: 'Reusable prompt')

      chat.cache_until_here

      expect(chat.to_llm.messages.last.cache_until_here?).to be(true)
    end

    it 'raises when the chat has no messages at all' do
      chat = Chat.create!(model: model_id)

      expect { chat.cache_until_here }.to raise_error(ArgumentError, 'No messages to cache')
    end
  end

  describe 'accounting' do
    it 'aggregates tokens and cost across persisted usage entries' do
      chat = Chat.create!(model: model_id)
      chat.ruby_llm_usages.create!(
        operation: 'chat', provider: 'openai', model: model_id, status: 'succeeded',
        input_tokens: 10, output_tokens: 20, input_cost: 0.1, output_cost: 0.2, total_cost: 0.3
      )

      expect(chat.tokens.input).to eq(10)
      expect(chat.tokens.output).to eq(20)
      expect(chat.cost.total).to be_within(0.0001).of(0.3)
    end

    it 'reports an empty cost for a chat that never ran' do
      chat = Chat.create!(model: model_id)

      expect(chat.cost.total).to be_nil
    end

    it 'uses a stored exact cost when token counts were unavailable' do
      chat = Chat.create!(model: model_id)
      message = chat.messages.create!(role: :assistant, content: 'done')
      chat.ruby_llm_usages.create!(
        message:,
        operation: 'chat',
        provider: 'openrouter',
        model: model_id,
        status: 'succeeded',
        total_cost: 0.0042
      )

      expect(chat.reload.cost.total).to eq(0.0042)
      expect(message.reload.cost.total).to eq(0.0042)
    end
  end

  describe 'delegation to the underlying chat' do
    it 'forwards generate, step, run_tools and complete?' do
      chat = Chat.create!(model: model_id)
      llm = chat.to_llm
      reply = RubyLLM::Message.new(role: :assistant, content: 'hi')
      allow(llm).to receive_messages(generate: reply, step: reply, run_tools: llm, complete?: true)

      expect(chat.generate).to eq(reply)
      expect(chat.step).to eq(reply)
      expect(chat.run_tools).to eq(chat)
      expect(chat).to be_complete
    end

    it 'forwards count_tokens and returns the count' do
      chat = Chat.create!(model: model_id)
      llm = chat.to_llm
      allow(llm).to receive(:count_tokens).and_return(42)

      expect(chat.count_tokens('Summarize this contract.')).to eq(42)
      expect(llm).to have_received(:count_tokens).with('Summarize this contract.')
    end

    it 'renders the payload with before_request hooks applied' do
      chat = Chat.create!(model: model_id)
      chat.before_request { |payload| payload[:metadata] = { user_id: 'u-1' } }
      chat.ask_later('Hello')

      expect(chat.render[:metadata]).to eq({ user_id: 'u-1' })
    end

    it 'forwards Chat configuration values' do
      chat = Chat.create!(model: model_id)
                 .with_server_tools(:web_search)
                 .with_tool_options(concurrency: :fibers)
                 .with_caching(ttl: '1h')
                 .with_compaction(at: 50_000)
                 .with_thinking(effort: :low)
                 .with_end_user('customer-42')
                 .with_fallbacks('gpt-4.1-mini')
                 .with_headers('X-Trace' => 'abc')
                 .with_provider_options(reasoning_effort: 'low')

      expect(chat.server_tools).to eq(chat.to_llm.server_tools)
      expect(chat.concurrency).to eq(:fibers)
      expect(chat.caching).to eq(ttl: '1h')
      expect(chat.compaction).to eq(at: 50_000)
      expect(chat.thinking).to eq(effort: :low)
      expect(chat.end_user).to eq('customer-42')
      expect(chat.fallbacks).to eq(chat.to_llm.fallbacks)
      expect(chat.headers).to eq('X-Trace' => 'abc')
      expect(chat.provider_options).to eq(reasoning_effort: 'low')
    end

    it 'persists completions added out of band' do
      chat = Chat.create!(model: model_id)
      response = RubyLLM::Message.new(role: :assistant, content: 'Batch response')

      expect(chat.add_completion(response)).to be(response)
      expect(chat.messages.reload.last.content).to eq('Batch response')
    end

    it 'is enumerable over persisted messages' do
      chat = Chat.create!(model: model_id)
      chat.add_message(role: :user, content: 'First')
      chat.add_message(role: :assistant, content: 'Second')

      expect(chat.map(&:content)).to eq(%w[First Second])
    end

    it 'classifies every method defined on Chat' do
      integration_methods = %i[
        approval_checker= cancellation_checker= fallback_errors raise_if_pending_tool_calls!
        tool_prefs usage_entries usage_entries= usage_recorder=
      ]

      missing_methods = RubyLLM::Chat.public_instance_methods(false) - Chat.public_instance_methods

      expect(missing_methods).to match_array(integration_methods)
    end
  end

  describe '#complete failure handling' do
    it 'destroys the blank assistant message and re-raises' do
      chat = Chat.create!(model: model_id)
      allow(chat.to_llm).to receive(:complete).and_raise(RubyLLM::ServerError.new('boom'))
      allow(RubyLLM.logger).to receive(:warn)
      chat.send(:persist_new_message)
      blank = chat.instance_variable_get(:@message)

      expect { chat.complete }.to raise_error(RubyLLM::ServerError)
      expect(Message.find_by(id: blank.id)).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/API call failed/)
    end

    it 'destroys the blank assistant message when the chat is cancelled' do
      chat = Chat.create!(model: model_id)
      allow(chat.to_llm).to receive(:complete).and_raise(RubyLLM::CancelledError.new('stopped'))
      allow(RubyLLM.logger).to receive(:warn)
      chat.send(:persist_new_message)
      blank = chat.instance_variable_get(:@message)

      expect { chat.complete }.to raise_error(RubyLLM::CancelledError)
      expect(Message.find_by(id: blank.id)).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/chat cancelled/)
    end
  end

  describe 'orphaned tool result cleanup' do
    it 'destroys a trailing tool-call message' do
      call = tool_call
      chat = Chat.create!(model: model_id)
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))

      chat.send(:cleanup_orphaned_tool_results)

      expect(chat.messages.reload).to be_empty
    end

    it 'destroys the whole round when a tool call is still unanswered' do
      answered = tool_call(name: 'answered')
      unanswered = tool_call(name: 'unanswered')
      chat = Chat.create!(model: model_id)
      chat.add_message(
        RubyLLM::Message.new(
          role: :assistant, content: '',
          tool_calls: { answered.id => answered, unanswered.id => unanswered }
        )
      )
      chat.add_message(RubyLLM::Message.new(role: :tool, content: 'done', tool_call_id: answered.id))

      chat.send(:cleanup_orphaned_tool_results)

      expect(chat.messages.reload).to be_empty
    end

    it 'keeps a completed round' do
      call = tool_call
      chat = Chat.create!(model: model_id)
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))
      chat.add_message(RubyLLM::Message.new(role: :tool, content: 'done', tool_call_id: call.id))

      chat.send(:cleanup_orphaned_tool_results)

      expect(chat.messages.reload.count).to eq(2)
    end

    it 'leaves a plain conversation alone' do
      chat = Chat.create!(model: model_id)
      chat.add_message(role: :user, content: 'hello')

      chat.send(:cleanup_orphaned_tool_results)

      expect(chat.messages.reload.count).to eq(1)
    end
  end

  describe 'tool call decisions' do
    it 'records a denial' do
      call = tool_call
      chat = Chat.create!(model: model_id)
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))

      expect(chat.deny(call.id)).to eq(chat)
      expect(RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call.id).approval).to eq('denied')
    end

    it 'accepts a RubyLLM::ToolCall value' do
      call = tool_call
      chat = Chat.create!(model: model_id)
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))

      chat.approve(call)

      expect(RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call.id).approval).to eq('approved')
    end

    it 'rejects an unknown tool call' do
      chat = Chat.create!(model: model_id)

      expect { chat.approve('call_missing') }.to raise_error(ArgumentError, /Unknown tool call: "call_missing"/)
    end
  end

  describe 'persistence callbacks' do
    it 'replaces a blank placeholder assistant message on the next round' do
      chat = Chat.create!(model: model_id)
      chat.send(:persist_new_message)
      first = chat.instance_variable_get(:@message)

      chat.send(:persist_new_message)

      expect(Message.find_by(id: first.id)).to be_nil
      expect(chat.messages.reload.count).to eq(1)
    end

    it 'keeps a placeholder that already carries tool calls' do
      call = tool_call
      chat = Chat.create!(model: model_id)
      chat.send(:persist_new_message)
      placeholder = chat.instance_variable_get(:@message)
      chat.send(:persist_tool_calls, { call.id => call }, message_record: placeholder)

      chat.send(:persist_new_message)

      expect(Message.find_by(id: placeholder.id)).to be_present
    end

    it 'keeps a placeholder that already carries attachments' do
      chat = Chat.create!(model: model_id)
      chat.send(:persist_new_message)
      placeholder = chat.instance_variable_get(:@message)
      placeholder.attachments.attach(io: StringIO.new('image'), filename: 'cat.png', content_type: 'image/png')

      chat.send(:persist_new_message)

      expect(Message.find_by(id: placeholder.id)).to be_present
    end

    it 'does nothing when the round produced no message' do
      chat = Chat.create!(model: model_id)

      expect { chat.send(:persist_message_completion, nil) }.not_to raise_error
    end

    it 'writes the response and links it to the tool call it answers' do
      call = tool_call
      chat = Chat.create!(model: model_id)
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))
      chat.send(:persist_new_message)

      chat.send(
        :persist_message_completion,
        RubyLLM::Message.new(
          role: :tool, content: 'done', tool_call_id: call.id,
          thinking: RubyLLM::Thinking.new(text: '', signature: 'sig'),
          citations: [RubyLLM::Citation.new(url: 'https://example.test')],
          finish_reason: 'stop'
        )
      )

      record = chat.instance_variable_get(:@message)
      expect(record.content).to eq('done')
      expect(record.reload.to_llm.thinking.text).to eq('')
      expect(record.thinking_signature).to eq('sig')
      expect(record.finish_reason).to eq(:stop)
      expect(record.citations.first.url).to eq('https://example.test')
      expect(RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call.id).result).to eq(record)
    end

    it 'skips attributes the message table does not carry' do
      chat = Chat.create!(model: model_id)
      allow(Message).to receive(:column_names).and_return(%w[role content])

      attributes = chat.send(:message_attributes, RubyLLM::Message.new(role: :assistant, content: 'hi'))

      expect(attributes).to eq(role: :assistant, content: 'hi')
    end

    it 'round-trips server tool calls and raw content through the row' do
      raw_block = { 'type' => 'server_tool_use', 'id' => 'srvtoolu_1', 'name' => 'web_search',
                    'input' => { 'query' => 'ruby' } }
      chat = Chat.create!(model: model_id)
      chat.send(:persist_new_message)

      chat.send(
        :persist_message_completion,
        RubyLLM::Message.new(
          role: :assistant, content: 'Found it.',
          server_tool_calls: [RubyLLM::ServerToolCall.new(type: 'server_tool_use', name: 'web_search',
                                                          id: 'srvtoolu_1', input: { 'query' => 'ruby' },
                                                          raw: raw_block)],
          raw_content: [raw_block, { 'type' => 'text', 'text' => 'Found it.' }],
          finish_reason: 'end_turn'
        )
      )

      record = chat.instance_variable_get(:@message)
      restored = record.to_llm
      expect(restored.server_tool_calls.first.type).to eq('server_tool_use')
      expect(restored.server_tool_calls.first.raw).to eq(RubyLLM::Utils.deep_symbolize_keys(raw_block))
      expect(restored.raw_content.length).to eq(2)
    end
  end

  describe 'tool call approval read back from the row' do
    def parked_chat_with(approval)
      call = tool_call
      chat = Chat.create!(model: model_id)
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))
      RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call.id).update!(approval: approval) if approval
      [chat, call]
    end

    it 'reads an approval, a denial, and no decision at all' do
      chat, call = parked_chat_with('approved')
      expect(chat.send(:persisted_tool_call_approval, call)).to be(true)

      chat, call = parked_chat_with('denied')
      expect(chat.send(:persisted_tool_call_approval, call)).to be(false)

      chat, call = parked_chat_with(nil)
      expect(chat.send(:persisted_tool_call_approval, call)).to be_nil
    end

    it 'is nil for a tool call this chat never made' do
      chat = Chat.create!(model: model_id)

      expect(chat.send(:persisted_tool_call_approval, tool_call)).to be_nil
    end
  end

  describe '#eager_load_messages' do
    it 'falls back to a plain list for an association without a class' do
      chat = Chat.create!(model: model_id)
      allow(chat).to receive(:messages_association).and_return([])

      expect(chat.send(:eager_load_messages)).to eq([])
    end
  end

  describe '#link_usage_entries' do
    it 'ignores entries the chat never recorded' do
      chat = Chat.create!(model: model_id)
      chat.send(:persist_new_message)
      message = RubyLLM::Message.new(role: :assistant, content: 'hi')

      expect { chat.send(:link_usage_entries, message) }.not_to raise_error
    end
  end

  describe '#cancelled?' do
    it 'reads the row when no chat has been built' do
      chat = Chat.create!(model: model_id)
      Chat.where(id: chat.id).update_all(cancelled: true)

      expect(Chat.find(chat.id)).to be_cancelled
    end
  end

  describe '#with_context before the chat is built' do
    it 'records the context before the chat is built' do
      chat = Chat.create!(model: model_id)
      context = RubyLLM.context { |config| config.request_timeout = 7 }

      chat.with_context(context)

      expect(chat.to_llm.provider.config.request_timeout).to eq(7)
    end
  end
end
