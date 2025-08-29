# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'
  include StreamingErrorHelpers

  describe 'streaming responses' do
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
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
        skip 'Perplexity reports different token counts for streaming vs non-streaming' if provider == :perplexity

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

  describe 'Error handling' do
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]

      context "with #{provider}/#{model}" do
        let(:chat) { RubyLLM.chat(model: model, provider: provider) }

        describe 'Faraday version 1' do # rubocop:disable RSpec/NestedGroups
          before do
            stub_const('Faraday::VERSION', '1.10.0')
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

        describe 'Faraday version 2' do # rubocop:disable RSpec/NestedGroups
          before do
            stub_const('Faraday::VERSION', '2.0.0')
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
