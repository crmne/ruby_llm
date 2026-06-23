# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::ChatCompletions::Batches do
  let(:protocol) { RubyLLM::Providers::XAI.batch_protocols.fetch(:chat_completions).allocate }

  describe '#xai_batch_request' do
    it 'wraps chat completion params as chat_get_completion requests' do
      request = {
        custom_id: '0',
        params: {
          model: 'grok-4.3',
          messages: [{ role: 'user', content: 'Hi' }],
          stream: false
        }
      }

      formatted = protocol.send(:xai_batch_request, request)

      expect(formatted).to eq(
        batch_request_id: '0',
        batch_request: {
          chat_get_completion: {
            model: 'grok-4.3',
            messages: [{ role: 'user', content: 'Hi' }]
          }
        }
      )
    end

    it 'keeps the model per request so mixed-model batches remain request-scoped' do
      requests = [
        { custom_id: '0', params: { model: 'grok-4.3', messages: [] } },
        { custom_id: '1', params: { model: 'grok-4.1', messages: [] } }
      ]

      formatted = requests.map { |request| protocol.send(:xai_batch_request, request) }

      expect(formatted.map { |request| request.dig(:batch_request, :chat_get_completion, :model) })
        .to eq(%w[grok-4.3 grok-4.1])
    end
  end

  describe '#parse_batch_response' do
    it 'marks batches complete when no requests are pending' do
      attributes = protocol.send(:parse_batch_response, {
                                   'batch_id' => 'batch_123',
                                   'state' => {
                                     'num_requests' => 2,
                                     'num_pending' => 0,
                                     'num_success' => 2,
                                     'num_error' => 0
                                   }
                                 })

      expect(attributes).to eq(
        id: 'batch_123',
        status: 'processing',
        completed: true,
        request_counts: {
          'num_requests' => 2,
          'num_pending' => 0,
          'num_success' => 2,
          'num_error' => 0
        }
      )
    end
  end

  describe '#parse_batch_result' do
    it 'parses successful chat_get_completion results' do
      result = {
        'batch_request_id' => '1',
        'batch_result' => {
          'response' => {
            'chat_get_completion' => {
              'model' => 'grok-4.3',
              'choices' => [{ 'message' => { 'role' => 'assistant', 'content' => 'Hello' } }],
              'usage' => { 'prompt_tokens' => 2, 'completion_tokens' => 1 }
            }
          }
        }
      }

      index, message = protocol.send(:parse_batch_result, result)

      expect(index).to eq(1)
      expect(message.content).to eq('Hello')
      expect(message.model_id).to eq('grok-4.3')
    end
  end
end
