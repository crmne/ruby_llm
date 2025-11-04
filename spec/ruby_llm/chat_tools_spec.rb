# frozen_string_literal: true

require 'spec_helper'

def supports_functions?(provider, model)
  return false if RubyLLM::Provider.providers[provider]&.local?

  model_info = RubyLLM.models.find(model)
  skip "#{model} doesn't support function calling" unless model_info&.supports_functions?
end

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  class Weather < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets current weather for a location'
    param :latitude, desc: 'Latitude (e.g., 52.5200)'
    param :longitude, desc: 'Longitude (e.g., 13.4050)'

    def execute(latitude:, longitude:)
      "Current weather at #{latitude}, #{longitude}: 15°C, Wind: 10 km/h"
    end
  end

  class BestLanguageToLearn < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets the best language to learn'

    def execute
      'Ruby'
    end
  end

  class BrokenTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets current weather'

    def execute
      raise 'This tool is broken'
    end
  end

  class DiceRoll < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Rolls a single six-sided die and returns the result'

    def execute
      { roll: rand(1..6) }
    end
  end

  class HaltingTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'A tool that halts conversation continuation'

    def execute
      halt 'Task completed successfully'
    end
  end

  class HandoffTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Delegates to a sub-agent and halts'
    param :query, desc: 'Query to pass to sub-agent'

    def execute(query:)
      sub_result = "Sub-agent handled: #{query}"
      halt sub_result
    end
  end

  class ContentReturningTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Returns a Content object with text and attachments'
    param :query, desc: 'Query to process'

    def execute(query:)
      RubyLLM::Content.new(
        "Processed: #{query}",
        File.join(__dir__, '..', 'fixtures', 'ruby.png')
      )
    end
  end

  class ParamsTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Has provider-specific params'
    with_params cache_control: { type: 'ephemeral' }

    def execute(**)
      'ok'
    end
  end

  class ArrayParamsTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Uses params DSL array support'

    params do
      array :tags, of: :string, description: 'List of tags to combine'
    end

    def execute(tags:)
      halt "Combined tags: #{tags.join(', ')}"
    end
  end

  class AnyOfParamsTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Uses params DSL any_of support'

    params do
      string :task, description: 'Task description'
      any_of :status, description: 'Optional task status' do
        string enum: %w[pending done]
        null
      end
    end

    def execute(task:, status:)
      halt "Task \"#{task}\" status #{status}"
    end
  end

  class ObjectParamsTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Uses params DSL object support'

    params do
      object :window, description: 'Time window to schedule' do
        string :start, description: 'ISO start'
        string :end, description: 'ISO end'
      end
    end

    def execute(window:)
      halt "Window from #{window['start']} to #{window['end']}"
    end
  end

  def assistant_tool_call_messages(chat)
    chat.messages.select { |message| message.role == :assistant && message.tool_call? }
  end

  def last_tool_call(chat)
    message = assistant_tool_call_messages(chat).last
    return [nil, nil] unless message

    [message, message.tool_calls.values.last]
  end

  def stringified_arguments(arguments)
    return {} unless arguments

    arguments.respond_to?(:transform_keys) ? arguments.transform_keys(&:to_s) : arguments
  end

  def tool_result_message_for(chat, tool_call)
    return nil unless tool_call

    chat.messages.reverse.find do |message|
      message.role == :tool && message.tool_call_id == tool_call.id
    end
  end

  describe 'function calling' do
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools" do
        supports_functions? provider, model

        skip 'Flaky test for deepseek - model asks for clarification instead of exec tools' if provider == :deepseek

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(Weather)
        # Disable thinking mode for qwen models
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'

        response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      model = 'claude-sonnet-4' if provider == :bedrock # haiku can't do parallel tool calls
      it "#{provider}/#{model} can use parallel tool calls" do
        supports_functions? provider, model
        skip 'gpustack/qwen3 does not support parallel tool calls properly' if provider == :gpustack && model == 'qwen3'

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tools(Weather, BestLanguageToLearn)
        # Disable thinking mode for qwen models
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'

        response = chat.ask("What's the weather in Berlin (52.5200, 13.4050) and what's the best language to learn?")
        expect(response.content).to include('15')
        expect(response.content).to include('10')
        expect(response.content).to include('Ruby')
        expect(chat.messages.count).to be(5)
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools in multi-turn conversations" do
        supports_functions? provider, model

        skip 'Flaky test for deepseek' if provider == :deepseek

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(Weather)
        # Disable thinking mode for qwen models
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'

        response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')

        response = chat.ask("What's the weather in Paris? (48.8575, 2.3514)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools without parameters" do
        supports_functions? provider, model

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(BestLanguageToLearn)
        # Disable thinking mode for qwen models
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'
        response = chat.ask("What's the best language to learn?")
        expect(response.content).to include('Ruby')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools without parameters in multi-turn streaming conversations" do
        supports_functions? provider, model
        if provider == :gpustack && model == 'qwen3'
          skip 'gpustack/qwen3 does not support streaming tool calls properly'
        end

        skip 'Mistral has a bug with tool arguments in multi-turn streaming' if provider == :mistral

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(BestLanguageToLearn)
                      .with_instructions('You must use tools whenever possible.')
        # Disable thinking mode for qwen models
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'
        chunks = []

        response = chat.ask("What's the best language to learn?") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('Ruby')

        response = chat.ask("Tell me again: what's the best language to learn?") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('Ruby')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools with multi-turn streaming conversations" do
        supports_functions? provider, model
        if provider == :gpustack && model == 'qwen3'
          skip 'gpustack/qwen3 does not support streaming tool calls properly'
        end

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(Weather)
        # Disable thinking mode for qwen models
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'
        chunks = []

        response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('15')
        expect(response.content).to include('10')

        response = chat.ask("What's the weather in Paris? (48.8575, 2.3514)") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('15')
        expect(response.content).to include('10')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can handle multiple tool calls in a single response" do
        supports_functions? provider, model

        skip 'Flaky test for gpustack/qwen3' if provider == :gpustack && model == 'qwen3'

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(DiceRoll)
                      .with_instructions(
                        'You must call the dice_roll tool exactly 3 times when asked to roll dice 3 times.'
                      )

        # Track tool calls to ensure all 3 are executed
        tool_call_count = 0

        original_execute = DiceRoll.instance_method(:execute)
        DiceRoll.define_method(:execute) do |**|
          tool_call_count += 1
          # Return a fixed result for VCR consistency
          { roll: tool_call_count }
        end

        response = chat.ask('Roll the dice 3 times')

        # Restore original method
        DiceRoll.define_method(:execute, original_execute)

        # Verify all 3 tool calls were made
        expect(tool_call_count).to eq(3)

        # Verify the response contains some dice roll results
        expect(response.content).to match(/\d+/) # Contains at least one number
        expect(response.content.downcase).to match(/roll|dice|result/) # Mentions rolling or results
      end

      it "#{provider}/#{model} can handle with_params" do
        supports_functions? provider, model

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(ParamsTool)
                      .with_instructions('You must call the params tool.')

        provider_instance = chat.instance_variable_get(:@provider)
        captured_payload = nil

        allow(provider_instance).to receive(:sync_response) do |_connection, payload, _|
          captured_payload = payload
          RubyLLM::Message.new(role: :assistant, content: 'ok')
        end

        chat.ask('Call the params tool for me')

        expect(captured_payload).not_to be_nil

        extracted = case provider
                    when :gemini, :vertexai
                      captured_payload.dig(:tools, 0, :functionDeclarations, 0, :cache_control)
                    else
                      captured_payload.dig(:tools, 0, :cache_control)
                    end

        expect(extracted).to eq(type: 'ephemeral')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} handles array params" do
        supports_functions? provider, model

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(ArrayParamsTool)
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'

        response = chat.ask(
          'Call the array params tool with tags ["red","blue"] and tell me the combined tags.'
        )

        expect(response).to be_a(RubyLLM::Tool::Halt)

        _message, tool_call = last_tool_call(chat)
        expect(tool_call).not_to be_nil
        expect(tool_call.name).to eq('array_params')

        arguments = stringified_arguments(tool_call.arguments)
        expect(arguments['tags']).to match_array(%w[red blue])
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} handles anyOf params" do
        supports_functions? provider, model

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(AnyOfParamsTool)
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'

        response = chat.ask(
          'Call the any-of params tool for task "Review PR" with status "pending" and report the result.'
        )

        expect(response).to be_a(RubyLLM::Tool::Halt)

        _message, tool_call = last_tool_call(chat)
        expect(tool_call).not_to be_nil
        expect(tool_call.name).to eq('any_of_params')

        arguments = stringified_arguments(tool_call.arguments)
        expect(arguments['task']).to eq('Review PR')
        expect(arguments['status']).to eq('pending')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} handles object params" do
        supports_functions? provider, model

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(ObjectParamsTool)
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'

        response = chat.ask(
          'Call the object params tool with window start 2025-01-01 and end 2025-01-02 and include the result.'
        )

        expect(response).to be_a(RubyLLM::Tool::Halt)

        _message, tool_call = last_tool_call(chat)
        expect(tool_call).not_to be_nil
        expect(tool_call.name).to eq('object_params')

        arguments = stringified_arguments(tool_call.arguments)
        expect(arguments['window']).to include(
          'start' => '2025-01-01',
          'end' => '2025-01-02'
        )
      end
    end
  end

  describe 'tool call callbacks' do
    it 'calls on_tool_call callback when tools are used' do
      tool_calls_received = []

      chat = RubyLLM.chat
                    .with_tool(Weather)
                    .on_tool_call { |tool_call| tool_calls_received << tool_call }

      response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")

      expect(tool_calls_received).not_to be_empty
      expect(tool_calls_received.first).to respond_to(:name)
      expect(tool_calls_received.first).to respond_to(:arguments)
      expect(tool_calls_received.first.name).to eq('weather')
      expect(response.content).to include('15')
      expect(response.content).to include('10')
    end

    it 'calls on_tool_result callback when tools return results' do
      tool_results_received = []

      chat = RubyLLM.chat
                    .with_tool(Weather)
                    .on_tool_result { |result| tool_results_received << result }

      response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")

      expect(tool_results_received).not_to be_empty
      expect(tool_results_received.first).to be_a(String)
      expect(tool_results_received.first).to include('15°C')
      expect(tool_results_received.first).to include('10 km/h')
      expect(response.content).to include('15')
      expect(response.content).to include('10')
    end

    it 'calls both on_tool_call and on_tool_result callbacks in order' do
      call_order = []

      chat = RubyLLM.chat
                    .with_tool(DiceRoll)
                    .on_tool_call { |_| call_order << :tool_call }
                    .on_tool_result { |_| call_order << :tool_result }

      chat.ask('Roll a die for me')

      expect(call_order).to eq(%i[tool_call tool_result])
    end
  end

  describe 'content object support' do
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} preserves Content objects returned from tools" do
        supports_functions? provider, model

        # Skip providers that don't support images in tool results
        skip "#{provider} doesn't support images in tool results" if provider.in?(%i[deepseek gpustack bedrock])

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(ContentReturningTool)

        chat.ask('Process this query: test data')

        tool_message = chat.messages.find { |m| m.role == :tool }
        expect(tool_message).not_to be_nil
        expect(tool_message.content).to be_a(RubyLLM::Content)
        expect(tool_message.content.text).to eq('Processed: test data')
        expect(tool_message.content.attachments).not_to be_empty
        expect(tool_message.content.attachments.first).to be_a(RubyLLM::Attachment)
        expect(tool_message.content.attachments.first.filename).to eq('ruby.png')
      end
    end
  end

  describe 'halt functionality' do
    it 'returns Halt object when tool halts' do
      chat = RubyLLM.chat.with_tool(HaltingTool)
      response = chat.ask('Execute the halting tool')

      expect(response).to be_a(RubyLLM::Tool::Halt)
      expect(response.content).to eq('Task completed successfully')
    end

    it 'does not continue conversation after halt' do
      call_count = 0
      original_complete = described_class.instance_method(:complete)

      # Monkey-patch to count complete calls
      described_class.define_method(:complete) do |&block|
        call_count += 1
        original_complete.bind_call(self, &block)
      end

      chat = RubyLLM.chat.with_tool(HaltingTool)
      response = chat.ask('Execute the halting tool')

      # Restore original method
      described_class.define_method(:complete, original_complete)

      # Should only call complete once (initial), not twice (no continuation)
      expect(call_count).to eq(1)
      expect(response).to be_a(RubyLLM::Tool::Halt)
    end

    it 'returns sub-agent result through halt' do
      chat = RubyLLM.chat.with_tool(HandoffTool)
      response = chat.ask('Please handle this query: What is Ruby?')

      expect(response).to be_a(RubyLLM::Tool::Halt)
      expect(response.content).to include('Sub-agent handled')
      expect(response.content).to include('What is Ruby?')
    end

    it 'adds halt content to conversation history' do
      chat = RubyLLM.chat.with_tool(HaltingTool)
      chat.ask('Execute the halting tool')

      # Check that the tool result was added to messages
      tool_message = chat.messages.find { |m| m.role == :tool }
      expect(tool_message).not_to be_nil
      expect(tool_message.content).to eq('Task completed successfully')
    end
  end

  describe 'error handling' do
    it 'raises an error when tool execution fails' do
      chat = RubyLLM.chat.with_tool(BrokenTool)

      expect { chat.ask('What is the weather?') }.to raise_error(RuntimeError) do |error|
        expect(error.message).to include('This tool is broken')
      end
    end
  end
end
