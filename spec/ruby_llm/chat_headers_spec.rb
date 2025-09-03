# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'
  describe '#with_headers' do
    it 'stores headers' do
      chat = RubyLLM.chat.with_headers('X-Custom-Header' => 'value')
      expect(chat.headers).to eq('X-Custom-Header' => 'value')
    end

    it 'returns self for chaining' do
      chat = RubyLLM.chat
      expect(chat.with_headers('X-Test' => 'test')).to eq(chat)
    end

    it 'passes headers to provider complete method' do
      chat = RubyLLM.chat
      provider = chat.instance_variable_get(:@provider)

      allow(provider).to receive(:complete).and_return(
        RubyLLM::Message.new(role: :assistant, content: 'Test response')
      )

      chat.with_headers('X-Custom' => 'header').ask('Test')

      expect(provider).to have_received(:complete).with(
        anything,
        hash_including(headers: { 'X-Custom' => 'header' })
      )
    end

    it 'allows chaining with other methods' do
      chat = RubyLLM.chat
                    .with_temperature(0.5)
                    .with_headers('X-Test' => 'value')
                    .with_params(max_tokens: 100)

      expect(chat.headers).to eq('X-Test' => 'value')
      expect(chat.params).to eq(max_tokens: 100)
      expect(chat.instance_variable_get(:@temperature)).to eq(0.5)
    end

    context 'with Anthropic beta headers' do
      it 'works with anthropic-beta header for fine-grained tool streaming' do
        chat = RubyLLM.chat(model: 'claude-3-5-haiku-20241022', provider: 'anthropic')
                      .with_headers('anthropic-beta' => 'fine-grained-tool-streaming-2025-05-14')

        response = chat.ask('Say "beta headers work"')
        expect(response.content).to include('beta headers work')
      end
    end

    context 'with header precedence' do
      it 'user headers do not override provider headers' do
        chat = RubyLLM.chat
        connection = chat.instance_variable_get(:@connection)
        provider = chat.instance_variable_get(:@provider)

        # Mock provider headers
        allow(provider).to receive_messages(
          headers: {
            'X-Api-Key' => 'provider-key',
            'Content-Type' => 'application/json'
          },
          parse_completion_response: RubyLLM::Message.new(role: :assistant, content: 'Test')
        )

        # Set user headers that try to override provider headers
        chat.with_headers(
          'X-Api-Key' => 'user-key',
          'X-Custom' => 'user-value'
        )

        # Mock the connection.post to verify header merging
        allow(connection).to receive(:post) do |_url, _payload, &block|
          req = instance_double(Faraday::Request)
          initial_headers = {
            'X-Api-Key' => 'provider-key',
            'Content-Type' => 'application/json'
          }

          allow(req).to receive(:headers).and_return(initial_headers)
          allow(req).to receive(:headers=) do |merged_headers|
            # Provider headers should take precedence
            expect(merged_headers['X-Api-Key']).to eq('provider-key')
            expect(merged_headers['Content-Type']).to eq('application/json')
            # User headers should be added
            expect(merged_headers['X-Custom']).to eq('user-value')
          end

          block&.call(req)

          instance_double(Faraday::Response,
                          body: {
                            'content' => [{ 'type' => 'text', 'text' => 'Test' }],
                            'model' => 'test-model'
                          })
        end

        chat.ask('Test')
      end
    end
  end
end
