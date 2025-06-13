# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM do
  describe '.logger' do
    let(:logger) { instance_double(Logger) }
    let(:log_file) { double }
    let(:log_level) { double }

    before do
      described_class.instance_variable_set(:@config, nil)
      described_class.instance_variable_set(:@logger, nil)
    end

    after do
      described_class.instance_variable_set(:@config, nil)
      described_class.instance_variable_set(:@logger, nil)
    end

    context 'with configuration options' do
      before do
        described_class.configure do |config|
          config.log_file = log_file
          config.log_level = log_level
        end
      end

      it 'returns a default Logger' do
        allow(Logger).to receive(:new).with(log_file, progname: 'RubyLLM', level: log_level).and_return(logger)

        expect(described_class.logger).to eq(logger)
      end
    end

    context 'with a custom logger' do
      before do
        described_class.configure do |config|
          config.logger = logger
          config.log_file = log_file
          config.log_level = log_level
        end
      end

      it 'returns a the custom Logger' do
        expect(described_class.logger).to eq(logger)
      end
    end
  end

  describe '.ask' do
    include_context 'with configured RubyLLM'

    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]

      it "#{provider}/#{model} can ask a question" do # rubocop:disable RSpec/MultipleExpectations
        response = described_class.ask("What's 2 + 2?", model: model, provider: provider)

        expect(response.content).to include('4')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end

      it "#{provider}/#{model} can say something" do # rubocop:disable RSpec/MultipleExpectations
        response = described_class.say("What's 2 + 2?", model: model, provider: provider)

        expect(response.content).to include('4')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end

      it "#{provider}/#{model} can ask a question with a tool" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        class AddTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
          description 'Add two numbers'
          param :number_one, type: :integer
          param :number_two, type: :integer

          def execute(number_one:, number_two:)
            number_one + number_two
          end
        end

        response = described_class.ask("What's 2 + 2?", model: model, provider: provider, tools: [AddTool])

        expect(response.content).to include('4')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end

      it "#{provider}/#{model} can set a temperature" do
        described_class.ask("What's 2 + 2?", model: model, provider: provider, temperature: 0.8)
        expect(described_class.instance_variable_get(:@ask_chat).instance_variable_get(:@temperature)).to eq(0.8)
      end

      it "#{provider}/#{model} successfully uses the system prompt" do # rubocop:disable RSpec/ExampleLength
        response = described_class.ask(
          'Tell me about the weather.',
          model: model,
          provider: provider,
          instructions: 'You must include the exact phrase "XKCD7392" in your response.'
        )

        expect(response.content).to match(/XKCD7392/i)
      end

      it "#{provider}/#{model} can use a context" do # rubocop:disable RSpec/ExampleLength
        context = described_class.context do |config|
          config.request_timeout = 500
        end

        described_class.ask(
          'Tell me about the weather.',
          context:,
          instructions: 'You must include the exact phrase "XKCD7392" in your response.'
        )

        ask_chat = described_class.instance_variable_get(:@ask_chat)
        expect(ask_chat.instance_variable_get(:@context).config.request_timeout).to eq(500)
      end

      it "#{provider}/#{model} can set event handler for new messages" do # rubocop:disable RSpec/ExampleLength
        message_count = 0

        described_class.ask(
          'Tell me about the weather.',
          model: model,
          provider: provider,
          on_new_message: -> { message_count += 1 }
        )

        expect(message_count).to eq(1)
      end

      it "#{provider}/#{model} can set event handler for end of message" do # rubocop:disable RSpec/ExampleLength
        message_count = 0

        described_class.ask(
          'Tell me about the weather.',
          model: model,
          provider: provider,
          on_end_message: ->(_response) { message_count += 1 }
        )

        expect(message_count).to eq(1)
      end
    end
  end
end
