# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe 'thinking mode functionality' do
    describe '#with_thinking' do
      context 'with thinking-capable models' do # rubocop:disable RSpec/NestedGroups
        THINKING_MODELS.each do |model_info|
          model = model_info[:model]
          provider = model_info[:provider]

          it "#{provider}/#{model} enables thinking mode successfully" do # rubocop:disable RSpec/MultipleExpectations
            chat = RubyLLM.chat(model: model, provider: provider)

            expect { chat.with_thinking }.not_to raise_error
            expect(chat.instance_variable_get(:@thinking)).to be true
            expect(chat.instance_variable_get(:@temperature)).to eq 1
          end

          it "#{provider}/#{model} accepts custom thinking parameters" do # rubocop:disable RSpec/MultipleExpectations
            chat = RubyLLM.chat(model: model, provider: provider)

            chat.with_thinking(budget: 20_000, temperature: 0.8)

            expect(chat.instance_variable_get(:@thinking)).to be true
            expect(chat.instance_variable_get(:@thinking_budget)).to eq 20_000
            expect(chat.instance_variable_get(:@temperature)).to eq 0.8
          end

          it "#{provider}/#{model} can disable thinking mode" do
            chat = RubyLLM.chat(model: model, provider: provider)

            chat.with_thinking(thinking: false)

            expect(chat.instance_variable_get(:@thinking)).to be false
          end

          it "#{provider}/#{model} can chain with other methods" do # rubocop:disable RSpec/MultipleExpectations
            chat = RubyLLM.chat(model: model, provider: provider)

            result = chat.with_thinking.with_temperature(0.5)

            expect(result).to be_a(described_class)
            expect(chat.instance_variable_get(:@thinking)).to be true
            # Temperature should be overridden by the subsequent with_temperature call
            expect(chat.instance_variable_get(:@temperature)).to eq 0.5
          end
        end
      end

      context 'with non-thinking models' do # rubocop:disable RSpec/NestedGroups
        NON_THINKING_MODELS.each do |model_info|
          model = model_info[:model]
          provider = model_info[:provider]

          it "#{provider}/#{model} raises UnsupportedThinkingError when enabling thinking" do
            chat = RubyLLM.chat(model: model, provider: provider)

            expect { chat.with_thinking }.to raise_error(RubyLLM::UnsupportedThinkingError)
          end

          it "#{provider}/#{model} allows disabling thinking without error" do # rubocop:disable RSpec/MultipleExpectations
            chat = RubyLLM.chat(model: model, provider: provider)

            expect { chat.with_thinking(thinking: false) }.not_to raise_error
            expect(chat.instance_variable_get(:@thinking)).to be false
          end
        end
      end
    end

    describe 'thinking mode integration with chat' do
      THINKING_MODELS.each do |model_info|
        model = model_info[:model]
        provider = model_info[:provider]

        it "#{provider}/#{model} can handle basic conversation with thinking enabled" do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
          chat = RubyLLM.chat(model: model, provider: provider)
          chat.with_thinking

          response = chat.ask("What's 2 + 2? Think through this step by step.")

          expect(response.content).to be_present
          expect(response.thinking).to be_present
          expect(response.role).to eq(:assistant)
          expect(response.input_tokens).to be_positive
          expect(response.output_tokens).to be_positive
        end

        it "#{provider}/#{model} maintains thinking mode across multiple turns" do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
          chat = RubyLLM.chat(model: model, provider: provider)
          chat.with_thinking

          first = chat.ask("What's 5 + 3?")
          expect(first.content).to include('8')

          second = chat.ask('Now multiply that result by 2')
          expect(second.content).to include('16')

          # Thinking mode should still be enabled
          expect(chat.instance_variable_get(:@thinking)).to be true
        end
      end
    end
  end
end
