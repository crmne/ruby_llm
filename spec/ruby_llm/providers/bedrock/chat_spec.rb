# frozen_string_literal: true

RSpec.describe RubyLLM::Providers::Bedrock::Chat do
  let(:model) { 'claude-3-sonnet' }
  let(:temperature) { 0.7 }
  let(:max_tokens) { 100 }
  let(:chat) { described_class.new(model: model, temperature: temperature, max_tokens: max_tokens) }
  let(:messages) do
    [
      { role: 'user', content: 'Hello!' }
    ]
  end

  describe '#chat' do
    let(:connection) { instance_double(Faraday::Connection) }
    let(:response) { instance_double(Faraday::Response) }

    before do
      allow(RubyLLM::Providers::Bedrock.config).to receive(:connection).and_return(connection)
      allow(RubyLLM::Providers::Bedrock.config).to receive(:access_key_id).and_return('test_key')
      allow(RubyLLM::Providers::Bedrock.config).to receive(:secret_access_key).and_return('test_secret')
      allow(RubyLLM::Providers::Bedrock.config).to receive(:region).and_return('us-east-1')
      allow(connection).to receive(:url_prefix).and_return(URI('https://bedrock-runtime.us-east-1.amazonaws.com'))
    end

    context 'with Claude model' do
      let(:model) { 'claude-3-sonnet' }

      it 'makes a request with correct parameters' do
        expect(connection).to receive(:post)
          .with('/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke')
          .and_return(response)

        allow(response).to receive(:success?).and_return(true)
        allow(response).to receive(:body).and_return({ completion: 'Hello there!' })

        result = chat.chat(messages: messages)
        expect(result).to eq({ role: 'assistant', content: 'Hello there!' })
      end

      context 'with streaming' do
        let(:chunks) { ['Hello', ' there', '!'] }
        let(:events) do
          chunks.map do |chunk|
            double('Event', data: JSON.generate({ completion: chunk }))
          end
        end

        it 'yields streamed responses' do
          expect(connection).to receive(:post)
            .with('/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke-with-response-stream')
            .and_return(response)

          allow(response).to receive(:success?).and_return(true)
          allow(response).to receive(:body).and_return(chunks)
          allow_any_instance_of(EventStreamParser).to receive(:feed).and_yield(*events)

          streamed = []
          chat.chat(messages: messages, stream: true).each do |chunk|
            streamed << chunk[:content]
          end

          expect(streamed).to eq(chunks)
        end
      end
    end

    context 'with Titan model' do
      let(:model) { 'titan' }

      it 'makes a request with correct parameters' do
        expect(connection).to receive(:post)
          .with('/model/amazon.titan-text-express-v1/invoke')
          .and_return(response)

        allow(response).to receive(:success?).and_return(true)
        allow(response).to receive(:body).and_return({ results: [{ outputText: 'Hello there!' }] })

        result = chat.chat(messages: messages)
        expect(result).to eq({ role: 'assistant', content: 'Hello there!' })
      end
    end

    context 'with unsupported model' do
      let(:model) { 'unsupported-model' }

      it 'raises an error' do
        expect {
          chat.chat(messages: messages)
        }.to raise_error(RubyLLM::Providers::Bedrock::Error, /Unsupported model/)
      end
    end

    context 'when request fails' do
      let(:error_response) { instance_double(Faraday::Response) }

      before do
        allow(connection).to receive(:post).and_return(error_response)
        allow(error_response).to receive(:success?).and_return(false)
        allow(error_response).to receive(:body).and_return('Error message')
      end

      it 'raises an error' do
        expect {
          chat.chat(messages: messages)
        }.to raise_error(RubyLLM::Providers::Bedrock::Error, /Request failed/)
      end
    end
  end
end 