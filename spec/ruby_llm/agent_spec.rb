# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  def with_prompt_root
    tmpdir = Dir.mktmpdir
    prompt_root = Pathname.new(tmpdir).join('app/prompts')
    prompt_root.mkpath
    allow(RubyLLM::Prompt).to receive(:root).and_return(prompt_root)
    yield prompt_root
  ensure
    FileUtils.rm_rf(tmpdir) if tmpdir
  end

  it 'builds a configured plain chat via .chat with runtime inputs' do
    tool_class = Class.new(RubyLLM::Tool) do
      def name = 'echo_tool'
    end

    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      inputs :display_name
      instructions { "Hello #{display_name}" }
      tools { [tool_class.new] }
      tool_options choice: :required, calls: :one
      caching { { ttl: '1h' } }
      provider_options { { max_tokens: 12 } }
    end

    chat = agent_class.chat(display_name: 'Ava')

    expect(chat.messages.first.role).to eq(:system)
    expect(chat.messages.first.content).to eq('Hello Ava')
    expect(chat.tools.keys).to include(:echo_tool)
    expect(chat.tool_prefs).to include(choice: :required, calls: :one)
    expect(chat.caching).to eq(ttl: '1h')
    expect(chat.tool_prefs).to include(choice: :required, calls: :one)
    expect(chat.provider_options).to eq(max_tokens: 12)
  end

  it 'applies max_output_tokens from the DSL macro' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      max_output_tokens 1000
    end

    expect(agent_class.chat.render[:max_output_tokens]).to eq(1000)
  end

  it 'applies tool_options separately from the declared tools' do
    tool_class = Class.new(RubyLLM::Tool) do
      def name = 'echo_tool'
    end

    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      tools tool_class.new
      tool_options choice: :required, calls: :one, concurrency: :fibers
    end

    expect(agent_class.tool_options).to eq(choice: :required, calls: :one, concurrency: :fibers)

    chat = agent_class.chat
    expect(chat.tools.keys).to include(:echo_tool)
    expect(chat.tool_prefs).to include(choice: :required, calls: :one)
    expect(chat.concurrency).to eq(:fibers)
  end

  it 'forwards the protocol model option to new chats' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-5-nano', protocol: :chat_completions
    end

    expect(agent_class.chat.instance_variable_get(:@protocol)).to eq(:chat_completions)
  end

  it 'defers tool_options evaluation to a block' do
    tool_class = Class.new(RubyLLM::Tool) do
      def name = 'echo_tool'
    end

    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      tools tool_class.new
      tool_options { { calls: :one } }
    end

    expect(agent_class.chat.tool_prefs[:calls]).to eq(:one)
  end

  it 'returns the configured model keywords from the bare model reader' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano', provider: :openai
    end

    expect(agent_class.model).to eq(model: 'gpt-4.1-nano', provider: :openai)
  end

  it 'exposes RubyLLM::Chat as chat in execution context for .chat' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      instructions { chat.class.name }
    end

    chat = agent_class.chat
    expect(chat.messages.first.content).to eq('RubyLLM::Chat')
  end

  it 'lets agents enable provider-default prompt caching' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      caching { {} }
    end

    expect(agent_class.chat.caching).to eq({})
  end

  it 'does not enable prompt caching unless configured' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
    end

    expect(agent_class.chat.caching).to be_nil
  end

  it 'lets agent instances clear prompt caching' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      caching { { retention: '24h' } }
    end
    agent = agent_class.new

    expect(agent.without_caching).to eq(agent.chat)
    expect(agent.caching).to be_nil
  end

  it 'rejects nil caching on agent instances, pointing to without_caching' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
    end
    agent = agent_class.new

    expect { agent.with_caching(nil) }.to raise_error(ArgumentError, /without_caching/)
  end

  it 'starts without instructions when the default prompt is missing' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
    end

    expect(agent_class.chat.messages).to be_empty
  end

  it 'raises when an explicitly referenced prompt is missing' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      instructions { prompt('instructions') }
    end

    expect { agent_class.chat }.to raise_error(RubyLLM::PromptNotFoundError, /Prompt file not found/)
  end

  it 'loads conventional instructions prompt automatically for named agents' do
    with_prompt_root do |prompt_root|
      path = prompt_root.join('spec_implicit_prompt_agent/instructions.txt.erb')
      path.dirname.mkpath
      path.write('Hello from <%= chat.class.name %>')

      agent_class = Class.new(RubyLLM::Agent) do
        model 'gpt-4.1-nano'
      end
      stub_const('SpecImplicitPromptAgent', agent_class)

      chat = SpecImplicitPromptAgent.chat

      expect(chat.messages.first.role).to eq(:system)
      expect(chat.messages.first.content).to eq('Hello from RubyLLM::Chat')
    end
  end

  it 'does not load a conventional prompt implicitly for anonymous agents' do
    with_prompt_root do |prompt_root|
      path = prompt_root.join('agent/instructions.txt.erb')
      path.dirname.mkpath
      path.write('Anonymous prompt')

      agent_class = Class.new(RubyLLM::Agent) do
        model 'gpt-4.1-nano'
      end

      expect(agent_class.chat.messages).to be_empty
    end
  end

  it 'supports inline schema DSL via schema do ... end' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      schema do
        string :verdict, enum: %w[pass revise]
        string :feedback
      end
    end

    chat = agent_class.chat

    expect(chat.schema).to include(name: 'Schema', strict: true, schema: include(type: 'object'))
    expect(chat.schema.dig(:schema, :properties)).to include(
      verdict: include(type: 'string'),
      feedback: include(type: 'string')
    )
  end

  it 'supports lambda schemas without DSL fallback' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      inputs :strict

      schema lambda {
        if strict
          {
            type: 'object',
            properties: { answer: { type: 'string' } },
            required: ['answer'],
            additionalProperties: false
          }
        end
      }
    end

    strict_chat = agent_class.chat(strict: true)
    loose_chat = agent_class.chat(strict: false)

    expect(strict_chat.schema).to include(name: 'response', strict: true, schema: include(type: 'object'))
    expect(loose_chat.schema).to be_nil
  end

  it 'can ask using the first configured chat model' do
    model_info = CHAT_MODELS.first

    agent_class = Class.new(RubyLLM::Agent) do
      model model_info[:model], provider: model_info[:provider]
      instructions 'Answer questions clearly.'
    end

    stub_const('SpecChatAgent', agent_class)

    response = SpecChatAgent.new.ask("What's 2 + 2?")
    expect(response.content).to include('4')
    expect(response.role).to eq(:assistant)
  end

  it 'delegates add_message to the underlying chat interface' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
    end

    agent = agent_class.new
    message = agent.add_message(role: :user, content: 'Hello')

    expect(message.role).to eq(:user)
    expect(message.content).to eq('Hello')
    expect(agent.chat.messages.last).to eq(message)
  end

  it 'exposes messages like RubyLLM::Chat' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
    end

    agent = agent_class.new
    agent.add_message(role: :user, content: 'First')

    expect(agent.messages).to eq(agent.chat.messages)
    expect(agent.messages.last.content).to eq('First')
  end

  it 'exposes cost like RubyLLM::Chat' do
    model = RubyLLM::Model.new(
      id: 'priced-model',
      name: 'Priced Model',
      provider: 'openai',
      pricing: {
        text_tokens: {
          standard: {
            input_per_million: 1.0,
            output_per_million: 2.0
          }
        }
      }
    )
    allow(RubyLLM.models).to receive(:find).and_call_original
    allow(RubyLLM.models).to receive(:find).with('priced-model').and_return(model)

    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
    end
    agent = agent_class.new

    agent.add_message(role: :assistant, content: 'Hi', input_tokens: 1_000, output_tokens: 2_000,
                      model: 'priced-model')

    expect(agent.cost.total).to eq(0.005)
  end

  it 'uses the agent chat model for cost when the response model id cannot be resolved' do
    model = RubyLLM::Model.new(
      id: 'priced-model',
      name: 'Priced Model',
      provider: 'openai',
      pricing: {
        text_tokens: {
          standard: {
            input_per_million: 1.0,
            output_per_million: 2.0
          }
        }
      }
    )

    chat = RubyLLM::Chat.allocate
    chat.instance_variable_set(:@model, model)
    chat.instance_variable_set(:@messages, [])
    agent = Class.new(described_class).new(chat:)

    response = agent.add_message(role: :assistant, content: 'Hi', input_tokens: 1_000, output_tokens: 2_000,
                                 model: 'provider-backend-version')

    expect(agent.model.cost_for(response).total).to eq(0.005)
    expect(agent.cost.total).to eq(0.005)
  end

  it 'delegates callback hooks to the underlying chat' do
    fake_chat = Class.new do
      attr_reader :events

      def initialize
        @events = []
      end

      def before_message(&)
        @events << :before_message
        self
      end

      def after_message(&)
        @events << :after_message
        self
      end

      def before_tool_call(&)
        @events << :before_tool_call
        self
      end

      def after_tool_result(&)
        @events << :after_tool_result
        self
      end

      def before_fallback(&)
        @events << :before_fallback
        self
      end

      def after_fallback(&)
        @events << :after_fallback
        self
      end
    end.new

    agent = Class.new(described_class).new(chat: fake_chat)

    expect(agent.before_message { :ok }).to eq(fake_chat)
    expect(agent.after_message { :ok }).to eq(fake_chat)
    expect(agent.before_tool_call { :ok }).to eq(fake_chat)
    expect(agent.after_tool_result { :ok }).to eq(fake_chat)
    expect(agent.before_fallback { :ok }).to eq(fake_chat)
    expect(agent.after_fallback { :ok }).to eq(fake_chat)
    expect(fake_chat.events).to eq(%i[
                                     before_message
                                     after_message
                                     before_tool_call
                                     after_tool_result
                                     before_fallback
                                     after_fallback
                                   ])
  end

  it 'applies class-configured fallbacks to new chats' do
    agent_class = Class.new(described_class) do
      model 'gpt-4.1-nano'
      fallbacks 'gpt-4.1-mini',
                RubyLLM.models.find('claude-haiku-4-5', :anthropic),
                on: RubyLLM::RateLimitError
    end

    chat = agent_class.chat

    expect(chat.fallbacks.map(&:id)).to eq(%w[gpt-4.1-mini claude-haiku-4-5-20251001])
    expect(chat.fallbacks.last.provider).to eq(:anthropic)
    expect(chat.fallback_errors).to eq([RubyLLM::RateLimitError])
  end

  it 'inherits fallback config to subclasses' do
    parent_class = Class.new(described_class) do
      model 'gpt-4.1-nano'
      fallbacks 'gpt-4.1-mini', on: RubyLLM::ServiceUnavailableError
    end

    child_class = Class.new(parent_class)

    expect(child_class.chat.fallbacks.map(&:id)).to eq(['gpt-4.1-mini'])
    expect(child_class.chat.fallback_errors).to eq([RubyLLM::ServiceUnavailableError])
  end

  it 'raises when fallback options are set without any fallback models' do
    expect do
      Class.new(described_class) do
        model 'gpt-4.1-nano'
        fallbacks on: RubyLLM::RateLimitError
      end
    end.to raise_error(ArgumentError, /fallback model/)
  end

  it 'supports Enumerable by delegating each to chat' do
    fake_chat = Class.new do
      def each(&block)
        return enum_for(:each) unless block_given?

        %w[first second].each(&block)
      end
    end.new

    agent = Class.new(described_class).new(chat: fake_chat)
    expect(agent.map(&:upcase)).to eq(%w[FIRST SECOND])
  end
end
