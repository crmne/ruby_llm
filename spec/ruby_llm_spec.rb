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

      it "#{provider}/#{model} can use system instructions" do # rubocop:disable RSpec/ExampleLength
        response = described_class.ask(
          'Tell me about the weather.',
          model: model,
          provider: provider,
          instructions: 'You must include the exact phrase "XKCD7392" in your response.'
        )

        expect(response.content).to match(/XKCD7392/i)
      end
    end
  end
end
