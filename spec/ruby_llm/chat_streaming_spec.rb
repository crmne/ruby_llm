# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe 'streaming responses' do
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} supports streaming responses" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        chunks = []

        chat.ask('Count from 1 to 3') do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
      end

      it "#{provider}/#{model} reports consistent token counts compared to non-streaming" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        if provider == :deepseek
          skip 'DeepSeek API returns different content/tokens for stream vs sync with this prompt. ' \
               'Skipping token consistency check.'
        end
        chat = RubyLLM.chat(model: model, provider: provider).with_temperature(0.0)
        chunks = []

        stream_message = chat.ask('Count from 1 to 3') do |chunk|
          chunks << chunk
        end

        chat = RubyLLM.chat(model: model, provider: provider).with_temperature(0.0)
        sync_message = chat.ask('Count from 1 to 3')

        expect(sync_message.input_tokens).to be_within(1).of(stream_message.input_tokens)
        expect(sync_message.output_tokens).to be_within(1).of(stream_message.output_tokens)
      end
    end
  end
end
