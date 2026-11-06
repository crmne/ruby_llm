# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  it 'uses block-configured credentials when creating and finding a chat' do
    RubyLLM.config.openai_api_key = nil
    agent = Class.new(described_class) do
      chat_class Chat
      model model_for(:openai, :temperature), provider: :openai
    end
    agent.context do |config|
      config.openai_api_key = 'agent-key'
      config.openai_api_base = 'https://example.com/v1'
    end

    chat = agent.create!

    expect(chat.to_llm.provider.config.openai_api_key).to eq('agent-key')
    expect(agent.find(chat.id).to_llm.provider.config.openai_api_base).to eq('https://example.com/v1')
    expect(RubyLLM.config.openai_api_key).to be_nil
  end

  it 'sets the owner of a found record after its context and protocol, before its instructions' do
    RubyLLM.config.openai_api_key = nil
    agent = Class.new(described_class) do
      chat_class Chat
      model model_for(:openai, :temperature), provider: :openai, protocol: :responses
      owner { chat.id }
      instructions { "Owner #{chat.owner}" }
    end
    agent.context do |config|
      config.openai_api_key = 'agent-key'
      config.openai_api_base = 'https://example.com/v1'
    end
    id = agent.create!.id
    built = []
    allow(Chat).to receive(:find).and_wrap_original do |find, *args|
      find.call(*args).tap do |record|
        allow(record).to receive(:build_llm_chat).and_wrap_original do |build|
          build.call.tap { built << [record.context&.config&.openai_api_base, record.protocol] }
        end
      end
    end

    record = agent.find(id)

    expect(built).to eq([['https://example.com/v1', :responses]])
    expect(record.owner).to eq(id)
    expect(record.to_llm.messages.first.content).to eq("Owner #{id}")
  end

  it 'applies callback macros to a found record, running them on an agent with its inputs' do
    events = []
    agent = Class.new(described_class) do
      chat_class Chat
      model model_for(:openai, :temperature)
      inputs :account
      after_message(:note, if: -> { account == 'acme' })

      define_method(:note) { |message| events << [account, chat.class, message.content] }
    end
    record = agent.find(agent.create!.id, account: 'acme')
    allow(record.to_llm.provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'Hello', input_tokens: 1, output_tokens: 1))

    record.ask('Hi')

    expect(events).to eq([['acme', Chat, 'Hello']])
    expect(record.messages_association.reload.map(&:content)).to eq(%w[Hi Hello])
  end

  describe 'rescue_from on records' do
    let(:agent) do
      Class.new(described_class) do
        chat_class Chat
        model model_for(:openai, :temperature)
        inputs :account
        rescue_from(RubyLLM::RateLimitError) { |error| [self.class, chat, account, error.class] }
      end
    end

    def rate_limited(record)
      allow(record.to_llm.instance_variable_get(:@provider))
        .to receive(:complete).and_raise(RubyLLM::RateLimitError.new('slow down'))
      record
    end

    it 'runs handlers on a record from ::find, the way a generated job calls it' do
      record = agent.find(agent.create!.id, account: 'acme')
      rate_limited(record)
      record.add_message(role: :user, content: 'hi')

      expect(record.complete).to eq([agent, record, 'acme', RubyLLM::RateLimitError])
    end

    it 'runs handlers on a record from ::create' do
      record = rate_limited(agent.create(account: 'acme'))

      expect(record.ask('hi')).to eq([agent, record, 'acme', RubyLLM::RateLimitError])
    end

    it 'runs handlers on a record from ::create!' do
      record = rate_limited(agent.create!(account: 'acme'))

      expect(record.ask('hi')).to eq([agent, record, 'acme', RubyLLM::RateLimitError])
    end

    it 'leaves a record found through the model alone' do
      record = rate_limited(Chat.find(agent.create!.id))

      expect { record.ask('hi') }.to raise_error(RubyLLM::RateLimitError)
    end
  end

  def write_prompt(agent_name, content)
    prompt_dir = Rails.root.join('app/prompts', agent_name)
    FileUtils.mkdir_p(prompt_dir)
    File.write(prompt_dir.join('instructions.txt.erb'), content)
    prompt_dir
  end

  it 'returns an invalid record from .create with its errors' do
    stub_const('RefusedChat', Class.new(Chat) { validate { errors.add(:base, 'Refused') } })
    agent = Class.new(described_class) do
      chat_class RefusedChat
      model model_for(:openai)
      instructions 'Be brief'
    end

    chat = agent.create

    expect(chat).not_to be_persisted
    expect(chat.errors[:base]).to eq(['Refused'])
  end

  it 'creates a Rails chat via .create! and renders prompt shorthand instructions' do
    prompt_dir = write_prompt(
      'spec_support_agent',
      'System for <%= display_name %> on chat <%= chat.id %>'
    )

    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      inputs :display_name
      instructions display_name: -> { display_name }
    end

    stub_const('SpecSupportAgent', agent_class)

    chat = SpecSupportAgent.create!(display_name: 'Ava')

    expect(chat).to be_a(Chat)
    expect(chat.messages.where(role: 'system').count).to eq(1)
    expect(chat.messages.find_by(role: 'system').content).to eq("System for Ava on chat #{chat.id}")
  ensure
    FileUtils.rm_rf(prompt_dir) if prompt_dir
  end

  it 'loads instructions.txt.erb when instructions is called without arguments' do
    prompt_dir = write_prompt(
      'spec_default_prompt_agent',
      'Default prompt for chat <%= chat.id %>'
    )

    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      instructions
    end

    stub_const('SpecDefaultPromptAgent', agent_class)

    chat = SpecDefaultPromptAgent.create!
    expect(chat.messages.find_by(role: 'system').content).to eq("Default prompt for chat #{chat.id}")
  ensure
    FileUtils.rm_rf(prompt_dir) if prompt_dir
  end

  it 'loads instructions.txt.erb automatically when a named agent has no instructions macro' do
    prompt_dir = write_prompt(
      'spec_implicit_rails_prompt_agent',
      'Implicit prompt for chat <%= chat.id %>'
    )

    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
    end

    stub_const('SpecImplicitRailsPromptAgent', agent_class)

    chat = SpecImplicitRailsPromptAgent.create!
    expect(chat.messages.find_by(role: 'system').content).to eq("Implicit prompt for chat #{chat.id}")
  ensure
    FileUtils.rm_rf(prompt_dir) if prompt_dir
  end

  it 'does not add instructions when no instructions macro or conventional prompt exists' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
    end

    stub_const('SpecNoInstructionsAgent', agent_class)

    chat = SpecNoInstructionsAgent.create!
    expect(chat.messages.where(role: 'system')).to be_empty
  end

  it 'raises when an explicitly referenced prompt file is missing' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      instructions { prompt('instructions') }
    end

    expect { agent_class.create! }.to raise_error(RubyLLM::PromptNotFoundError, /Prompt file not found/)
  end

  it 'exposes chat_class record as chat in execution context for .create! and .find' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      instructions { "chat-class: #{chat.class.name}" }
    end

    stub_const('SpecChatContextAgent', agent_class)

    created = SpecChatContextAgent.create!
    expect(created.messages.find_by(role: 'system').content).to eq('chat-class: Chat')

    loaded = SpecChatContextAgent.find(created.id)
    runtime_chat = loaded.instance_variable_get(:@chat)
    expect(runtime_chat.messages.first.content).to eq('chat-class: Chat')
  end

  it 'picks the model with a block when creating a Rails chat' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      inputs :quality
      model { quality == :high ? model_for(:openai, :alternate_chat) : model_for(:openai, :temperature) }
    end

    stub_const('SpecDynamicModelAgent', agent_class)

    expect(SpecDynamicModelAgent.create!(quality: :high).model_id).to eq(model_for(:openai, :alternate_chat))
    expect(SpecDynamicModelAgent.create!(quality: :low).model_id).to eq(model_for(:openai, :temperature))
  end

  it 'resolves a deferred context from inputs for Rails chats' do
    seen_chats = []
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      inputs :timeout
      send(:context) do
        seen_chats << chat
        RubyLLM.context { |config| config.request_timeout = timeout }
      end
    end

    stub_const('SpecDynamicContextAgent', agent_class)

    created = SpecDynamicContextAgent.create!(timeout: 42)
    loaded = SpecDynamicContextAgent.find(created.id, timeout: 84)

    expect(seen_chats.first).to equal(created)
    expect(seen_chats.last).to equal(loaded)
    expect(created.context.config.request_timeout).to eq(42)
    expect(created.to_llm.provider.config.request_timeout).to eq(42)
    expect(loaded.context.config.request_timeout).to eq(84)
    expect(loaded.to_llm.provider.config.request_timeout).to eq(84)
  end

  it 'finds a Rails chat and applies runtime instructions without persisting them' do
    prompt_dir = write_prompt(
      'spec_runtime_agent',
      'System for <%= display_name %> on chat <%= chat.id %>'
    )

    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      inputs :display_name
      instructions display_name: -> { display_name }
    end

    stub_const('SpecRuntimeAgent', agent_class)

    chat = SpecRuntimeAgent.create!(display_name: 'Ava')
    persisted_system = chat.messages.find_by(role: 'system').content

    loaded = SpecRuntimeAgent.find(chat.id, display_name: 'Bea')
    runtime_chat = loaded.instance_variable_get(:@chat)

    expect(loaded.messages.where(role: 'system').count).to eq(1)
    expect(loaded.messages.find_by(role: 'system').content).to eq(persisted_system)
    expect(runtime_chat.messages.first.content).to eq("System for Bea on chat #{chat.id}")
  ensure
    FileUtils.rm_rf(prompt_dir) if prompt_dir
  end

  it 'combines persisted and unpersisted instruction declarations' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)

      instructions 'Stable policy', cache_until_here: true
      instructions append: true, persist: false do
        "Current chat #{chat.id}"
      end
    end

    stub_const('SpecLayeredInstructionsAgent', agent_class)

    created = SpecLayeredInstructionsAgent.create!

    expect(created.messages.where(role: 'system').pluck(:content, :cache_until_here)).to eq([
                                                                                              ['Stable policy', true]
                                                                                            ])
    expect(created.to_llm.messages.map(&:content)).to eq([
                                                           'Stable policy',
                                                           "Current chat #{created.id}"
                                                         ])

    loaded = SpecLayeredInstructionsAgent.find(created.id)
    expect(loaded.messages.where(role: 'system').pluck(:content, :cache_until_here)).to eq([
                                                                                             ['Stable policy', true]
                                                                                           ])
    expect(loaded.to_llm.messages.map(&:content)).to eq([
                                                          'Stable policy',
                                                          "Current chat #{created.id}"
                                                        ])
    expect(loaded.to_llm.messages.map(&:cache_until_here?)).to eq([true, false])
  end

  it 'leaves unchanged system rows in place when applied to an existing record' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)

      instructions 'You are a helpful assistant.'
      instructions 'Answer in French.', append: true
    end
    record = agent_class.create!
    record.add_message(role: :user, content: 'Hello')
    rows = record.messages.order(:id).pluck(:id, :role, :content)

    2.times { agent_class.new(chat: Chat.find(record.id)) }

    expect(record.messages.order(:id).pluck(:id, :role, :content)).to eq(rows)
    expect(agent_class.new(chat: Chat.find(record.id)).messages.map(&:content))
      .to eq(['You are a helpful assistant.', 'Answer in French.', 'Hello'])
  end

  it 'replaces system rows when the declared instructions change' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      inputs :language

      instructions 'You are a helpful assistant.'
      instructions(append: true) { "Answer in #{language}." }
      instructions(append: true) { 'Be brief.' if language == 'French' }
    end
    record = agent_class.create!(language: 'French')
    system_rows = -> { record.messages.where(role: 'system').order(:id).pluck(:content, :cache_until_here) }

    agent_class.new(chat: Chat.find(record.id), language: 'Dutch')
    expect(system_rows.call).to eq([['You are a helpful assistant.', false], ['Answer in Dutch.', false]])

    cached = Class.new(agent_class) do
      instructions 'You are a helpful assistant.', cache_until_here: true
      instructions(append: true) { "Answer in #{language}." }
    end
    cached.new(chat: Chat.find(record.id), language: 'Dutch')
    expect(system_rows.call).to eq([['You are a helpful assistant.', true], ['Answer in Dutch.', false]])
  end

  it 'syncs only persistent instruction declarations' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      inputs :version

      instructions { "Stable #{version}" }
      instructions append: true, persist: false do
        "Runtime #{version}"
      end
    end

    stub_const('SpecInstructionPersistenceAgent', agent_class)

    chat = SpecInstructionPersistenceAgent.create!(version: 'one')
    SpecInstructionPersistenceAgent.sync_instructions(chat, version: 'two')

    expect(chat.reload.messages.where(role: 'system').pluck(:content)).to eq(['Stable two'])
  end

  it 'preserves inherited instruction persistence and caching on create and find' do
    parent = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      instructions 'Inherited policy', cache_until_here: true
      instructions(append: true, persist: false) { "Runtime chat #{chat.id}" }
    end
    child = Class.new(parent)

    created = child.create!
    loaded = child.find(created.id)

    [created, loaded].each do |record|
      expect(record.messages.where(role: 'system').pluck(:content, :cache_until_here)).to eq([
                                                                                               ['Inherited policy',
                                                                                                true]
                                                                                             ])
      expect(record.to_llm.messages.map(&:content)).to eq(['Inherited policy', "Runtime chat #{created.id}"])
      expect(record.to_llm.messages.map(&:cache_until_here?)).to eq([true, false])
    end
  end

  it 'prefers child declarations and prompts to inherited instructions on Rails records' do
    prompt_dir = write_prompt('spec_inherited_rails_agent', 'Child prompt')
    parent = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      instructions 'Inherited policy', cache_until_here: true
    end
    child = stub_const('SpecInheritedRailsAgent', Class.new(parent))

    record = child.create!
    expect(record.messages.where(role: 'system').pluck(:content, :cache_until_here)).to eq([['Child prompt', false]])

    child.instructions 'Child inline instructions', append: true
    child.sync_instructions(record)

    expect(record.reload.messages.where(role: 'system').pluck(:content)).to eq(['Child prompt',
                                                                                'Child inline instructions'])
    expect(child.create!.messages.where(role: 'system').pluck(:content)).to eq(['Child inline instructions'])
  ensure
    FileUtils.rm_rf(prompt_dir) if prompt_dir
  end

  it 'keeps runtime instructions on repeated to_llm calls after find' do
    prompt_dir = write_prompt(
      'spec_runtime_reuse_agent',
      'System for <%= display_name %> on chat <%= chat.id %>'
    )

    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      inputs :display_name
      instructions display_name: -> { display_name }
    end

    stub_const('SpecRuntimeReuseAgent', agent_class)

    chat = SpecRuntimeReuseAgent.create!(display_name: 'Ava')
    loaded = SpecRuntimeReuseAgent.find(chat.id, display_name: 'Bea')

    expect(loaded.to_llm.messages.first.content).to eq("System for Bea on chat #{chat.id}")
    expect(loaded.to_llm.messages.first.content).to eq("System for Bea on chat #{chat.id}")
  ensure
    FileUtils.rm_rf(prompt_dir) if prompt_dir
  end

  it 'syncs instructions explicitly via .sync_instructions' do
    prompt_dir = write_prompt(
      'spec_sync_agent',
      'System for <%= display_name %> on chat <%= chat.id %>'
    )

    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
      inputs :display_name
      instructions display_name: -> { display_name }
    end

    stub_const('SpecSyncAgent', agent_class)

    chat = SpecSyncAgent.create!(display_name: 'Ava')
    expect(chat.messages.find_by(role: 'system').content).to eq("System for Ava on chat #{chat.id}")

    SpecSyncAgent.find(chat.id, display_name: 'Bea')
    expect(chat.reload.messages.find_by(role: 'system').content).to eq("System for Ava on chat #{chat.id}")

    SpecSyncAgent.sync_instructions(chat, display_name: 'Bea')
    expect(chat.reload.messages.find_by(role: 'system').content).to eq("System for Bea on chat #{chat.id}")

    SpecSyncAgent.sync_instructions(chat.id, display_name: 'Cia')
    expect(chat.reload.messages.find_by(role: 'system').content).to eq("System for Cia on chat #{chat.id}")
  ensure
    FileUtils.rm_rf(prompt_dir) if prompt_dir
  end

  it 'raises when .create! is used without chat_class' do
    agent_class = Class.new(RubyLLM::Agent) do
      model model_for(:openai, :temperature)
    end

    expect do
      agent_class.create!
    end.to raise_error(ArgumentError, /chat_class must be configured/)
  end

  it 'propagates assume_model_exists from class config when using find' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model 'not-a-real-model', provider: :openai, assume_model_exists: true
      instructions 'Hello'
    end

    stub_const('SpecAssumeExistsAgent', agent_class)

    created = SpecAssumeExistsAgent.create!
    expect { SpecAssumeExistsAgent.find(created.id) }.not_to raise_error
  end

  it 'propagates assume_model_exists from class config when using sync_instructions with id' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model 'not-a-real-model', provider: :openai, assume_model_exists: true
      instructions 'Hello'
    end

    stub_const('SpecAssumeExistsSyncAgent', agent_class)

    created = SpecAssumeExistsSyncAgent.create!
    expect { SpecAssumeExistsSyncAgent.sync_instructions(created.id) }.not_to raise_error
  end

  it 'propagates assume_model_exists from class config when initializing with a reloaded chat record' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model 'not-a-real-model', provider: :openai, assume_model_exists: true
      instructions 'Hello'
    end

    stub_const('SpecAssumeExistsInitAgent', agent_class)

    created = SpecAssumeExistsInitAgent.create!
    reloaded = Chat.find(created.id)
    expect { SpecAssumeExistsInitAgent.new(chat: reloaded) }.not_to raise_error
  end

  it 'forwards the protocol model option to created and found Rails chat records' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai), protocol: :chat_completions
      instructions 'Hello'
    end

    stub_const('SpecProtocolAgent', agent_class)

    created = SpecProtocolAgent.create!
    expect(created.to_llm.instance_variable_get(:@protocol)).to eq(:chat_completions)

    found = SpecProtocolAgent.find(created.id)
    expect(found.to_llm.instance_variable_get(:@protocol)).to eq(:chat_completions)
  end

  context 'when the caller passes a model' do
    let(:agent_class) do
      Class.new(described_class) do
        chat_class Chat
        model model_for(:anthropic), provider: :anthropic
        instructions 'Hello'
      end
    end
    let(:declared_with_options) do
      Class.new(described_class) do
        chat_class Chat
        model 'unlisted-model', provider: :anthropic, protocol: :anthropic, assume_model_exists: true
      end
    end

    def model_and_provider(record)
      [record.model_id, record.provider, record.to_llm.model.id, record.to_llm.provider.slug]
    end

    def llm_protocol(record)
      record.to_llm.instance_variable_get(:@protocol)
    end

    it 'replaces the declared model and its provider on create!' do
      created = agent_class.create!(model: model_for(:openai))

      expect(model_and_provider(created)).to eq([model_for(:openai), 'openai', model_for(:openai), 'openai'])
    end

    it 'replaces the declared model and its provider on create' do
      created = agent_class.create(model: model_for(:openai))

      expect(created).to be_persisted
      expect(model_and_provider(created)).to eq([model_for(:openai), 'openai', model_for(:openai), 'openai'])
    end

    it 'keeps the replacement when the record is found again' do
      created = agent_class.create!(model: model_for(:openai))

      found = agent_class.find(created.id)

      expect(model_and_provider(found)).to eq([model_for(:openai), 'openai', model_for(:openai), 'openai'])
    end

    it 'uses a provider the caller also passes' do
      created = agent_class.create!(model: 'unlisted-model', provider: :openai, assume_model_exists: true)

      expect(created.model.provider).to eq('openai')
      expect(created.to_llm.provider.slug).to eq('openai')
    end

    it 'does not apply options declared for the replaced model when creating' do
      created = declared_with_options.create!(model: model_for(:openai))

      expect(model_and_provider(created)).to eq([model_for(:openai), 'openai', model_for(:openai), 'openai'])
      expect(created.assume_model_exists).to be_nil
      expect(llm_protocol(created)).to be_nil
    end

    it 'does not apply options declared for the replaced model when finding' do
      created = declared_with_options.create!(model: model_for(:openai))

      found = declared_with_options.find(created.id)

      expect(found.assume_model_exists).to be_nil
      expect(llm_protocol(found)).to be_nil
    end

    it 'does not apply options declared for the replaced model when binding or syncing a record' do
      created = declared_with_options.create!(model: model_for(:openai))

      bound = declared_with_options.new(chat: Chat.find(created.id)).chat
      synced = declared_with_options.sync_instructions(created.id)

      expect(llm_protocol(bound)).to be_nil
      expect(llm_protocol(synced)).to be_nil
    end

    it 'does not apply options declared for the model a found record switched away from' do
      created = declared_with_options.create!.with_model(model_for(:openai))

      found = declared_with_options.find(created.id)

      expect(llm_protocol(created)).to be_nil
      expect(llm_protocol(found)).to be_nil
    end

    it 'keeps a protocol the caller passes alongside the model' do
      created = declared_with_options.create!(model: model_for(:openai), protocol: :chat_completions)

      expect(llm_protocol(created)).to eq(:chat_completions)
    end

    it 'keeps a protocol the caller passes for the declared model' do
      declared = Class.new(described_class) do
        chat_class Chat
        model model_for(:openai), provider: :openai, protocol: :responses
      end

      created = declared.create!(protocol: :chat_completions)

      expect(llm_protocol(created)).to eq(:chat_completions)
    end

    it 'applies declared options to a found record whose model is an alias of the declared one' do
      declared = Class.new(described_class) do
        chat_class Chat
        model 'claude-sonnet-5', provider: :openrouter, protocol: :chat_completions
      end
      created = declared.create!

      found = declared.find(created.id)

      expect(found.model_id).to eq('anthropic/claude-sonnet-5')
      expect(llm_protocol(found)).to eq(:chat_completions)
    end

    it 'keeps a declared provider when the agent declares no model' do
      declared = Class.new(described_class) do
        chat_class Chat
        model provider: :openai, assume_model_exists: true
      end

      created = declared.create!(model: 'unlisted-model')

      expect(created.model.provider).to eq('openai')
      expect(created.to_llm.provider.slug).to eq('openai')
    end
  end

  it 'raises when .sync_instructions is used without chat_class' do
    agent_class = Class.new(RubyLLM::Agent) do
      model model_for(:openai, :temperature)
    end

    expect do
      agent_class.sync_instructions(1)
    end.to raise_error(ArgumentError, /chat_class must be configured/)
  end
end
