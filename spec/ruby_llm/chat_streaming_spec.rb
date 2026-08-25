# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  include StreamingErrorHelpers

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

      it "#{provider}/#{model} reports consistent token counts compared to non-streaming" do
        model = 'gpt-4.1-nano' if provider == :openai # gpt-5 rejects the temperature this example sets
        skip 'Perplexity reports different token counts for streaming vs non-streaming' if provider == :perplexity
        skip 'Azure reports different token counts for streaming vs non-streaming' if provider == :azure
        skip 'xAI reports different token counts for streaming vs non-streaming' if provider == :xai
        if provider == :gpustack && model == 'qwen3'
          skip 'GPUStack/Qwen3 reports different token counts for streaming vs non-streaming'
        end

        chat = basic_chat(model: model, provider: provider, temperature: 0.0)
        chunks = []

        stream_message = chat.ask('Count from 1 to 3') do |chunk|
          chunks << chunk
        end

        chat = basic_chat(model: model, provider: provider, temperature: 0.0)
        sync_message = chat.ask('Count from 1 to 3')

        expect(sync_message.tokens.input).to be_within(1).of(stream_message.tokens.input)
        expect(sync_message.tokens.output).to be_within(2).of(stream_message.tokens.output)
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
      chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini)

      chunks = []
      response = chat.ask('What is 2+2? Think step by step.') do |chunk|
        chunks << chunk
      end

      final_chunk = chunks.last
      expect(response.tokens.output).to eq(final_chunk.tokens.output) if final_chunk.tokens.output
    end
  end
end
