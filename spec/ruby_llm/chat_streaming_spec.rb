# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  include StreamingErrorHelpers

  def prompt_token_count(message)
    tokens = message.tokens
    tokens.input.to_i + tokens.cache_read.to_i + tokens.cache_write.to_i
  end

  def visible_output_token_count(message)
    return if message.thinking && message.tokens.thinking.nil?

    message.tokens.output - message.tokens.thinking.to_i
  end

  describe 'streaming responses' do
    each_model(CHAT_MODELS) do |provider, model|
      it "#{provider}/#{model} supports streaming responses" do
        chat = RubyLLM.chat(model: model, provider: provider)
        chunks = []

        response = chat.ask('Count from 1 to 3') do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.raw).to be_present
        expect(response.raw.headers).to be_present
        expect(response.raw.status).to be_present
        expect(response.raw.status).to eq(200)
        expect(response.raw.env.request_body).to be_present
      end

      token_model = provider == :openai ? model_for(:openai, :temperature) : model
      it "#{provider}/#{token_model} reports token usage with and without streaming" do
        model = token_model

        chat = basic_chat(model: model, provider: provider, temperature: 0.0)
        # DeepSeek ignores temperature while thinking is enabled.
        chat.with_thinking(false) if provider == :deepseek
        chunks = []
        prompt = 'Reply with exactly: 1, 2, 3'

        stream_message = chat.ask(prompt) do |chunk|
          chunks << chunk
        end

        chat = basic_chat(model: model, provider: provider, temperature: 0.0)
        chat.with_thinking(false) if provider == :deepseek
        sync_message = chat.ask(prompt)

        expect(stream_message.content.strip).to eq('1, 2, 3')
        expect(sync_message.content.strip).to eq(stream_message.content.strip)
        [stream_message, sync_message].each do |message|
          %i[input cache_read cache_write thinking].each do |component|
            count = message.tokens.public_send(component)
            expect(count).to be_a(Integer).and be >= 0 unless count.nil?
          end
          expect(prompt_token_count(message)).to be > 0
          expect(message.tokens.output).to be_a(Integer).and be > 0
          expect(message.tokens.output).to be >= message.tokens.thinking.to_i
        end
        expect(stream_message.tokens.to_h).to eq(chunks.reduce({}) { |usage, chunk| usage.merge(chunk.tokens.to_h) })

        stream_output = visible_output_token_count(stream_message)
        sync_output = visible_output_token_count(sync_message)
        expect(sync_output).to be_within(2).of(stream_output) if sync_output && stream_output
      end
    end
  end

  describe 'Error handling' do
    each_model(CHAT_MODELS) do |provider, model|
      context "with #{provider}/#{model}" do
        let(:chat) { RubyLLM.chat(model: model, provider: provider) }

        { '1' => '1.10.0', '2' => '2.0.0' }.each do |major, faraday_version|
          describe "Faraday version #{major}" do # rubocop:disable RSpec/NestedGroups
            before do
              stub_const('Faraday::VERSION', faraday_version)
            end

            it "#{provider}/#{model} supports handling streaming error chunks" do
              # Testing if error handling is now implemented

              stub_error_response(provider, :chunk)

              chunks = []

              expect do
                chat.ask('Count from 1 to 3') do |chunk|
                  chunks << chunk
                end
              end.to raise_error(expected_error_for(provider))
            end

            it "#{provider}/#{model} supports handling streaming error events" do
              skip 'Bedrock uses AWS Event Stream format, not SSE events' if provider == :bedrock

              # Testing if error handling is now implemented

              stub_error_response(provider, :event)

              chunks = []

              expect do
                chat.ask('Count from 1 to 3') do |chunk|
                  chunks << chunk
                end
              end.to raise_error(expected_error_for(provider))
            end
          end
        end
      end
    end
  end

  describe 'Gemini token accounting' do
    it 'correctly sums candidatesTokenCount and thoughtsTokenCount in streaming' do
      chat = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)

      chunks = []
      response = chat.ask('What is 2+2? Think step by step.') do |chunk|
        chunks << chunk
      end

      final_chunk = chunks.last
      expect(response.tokens.output).to eq(final_chunk.tokens.output) if final_chunk.tokens.output
    end
  end
end
