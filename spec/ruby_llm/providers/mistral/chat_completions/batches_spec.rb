# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::ChatCompletions::Batches do
  let(:protocol) { RubyLLM::Providers::Mistral.batch_protocols.fetch(:chat_completions).allocate }

  describe '#mistral_batch_request' do
    it 'moves the model to the batch job and leaves the chat body model-free' do
      request = {
        custom_id: '0',
        model: 'mistral-small-latest',
        params: {
          model: 'mistral-small-latest',
          messages: [{ role: 'user', content: 'Hi' }],
          stream: false
        }
      }

      formatted = protocol.send(:mistral_batch_request, request)

      expect(formatted).to eq(
        custom_id: '0',
        body: {
          messages: [{ role: 'user', content: 'Hi' }]
        }
      )
    end
  end

  describe '#create_batch' do
    it 'rejects mixed-model jobs' do
      requests = [
        { model: 'mistral-small-latest', params: {} },
        { model: 'mistral-large-latest', params: {} }
      ]

      expect { protocol.create_batch(requests) }
        .to raise_error(RubyLLM::Error, /one model/)
    end
  end

  describe '#parse_batch_response' do
    it 'marks successful jobs complete and normalizes counts' do
      attributes = protocol.send(:parse_batch_response, {
                                   'id' => 'job_123',
                                   'status' => 'SUCCESS',
                                   'total_requests' => 2,
                                   'completed_requests' => 2,
                                   'succeeded_requests' => 2,
                                   'failed_requests' => 0
                                 })

      expect(attributes).to eq(
        id: 'job_123',
        status: 'SUCCESS',
        completed: true,
        request_counts: {
          'total' => 2,
          'completed' => 2,
          'succeeded' => 2,
          'failed' => 0
        }
      )
    end

    it 'leaves cancellation requests running' do
      expect(protocol.send(:parse_batch_response, 'id' => 'job_123', 'status' => 'CANCELLATION_REQUESTED'))
        .to include(completed: false)
    end
  end

  describe '#parse_batch_result' do
    it 'parses successful chat completion results' do
      line = {
        'custom_id' => '1',
        'response' => {
          'body' => {
            'model' => 'mistral-small-latest',
            'choices' => [{ 'message' => { 'role' => 'assistant', 'content' => 'Bonjour' } }],
            'usage' => { 'prompt_tokens' => 3, 'completion_tokens' => 2 }
          }
        }
      }

      index, message = protocol.send(:parse_batch_result, line)

      expect(index).to eq(1)
      expect(message.content).to eq('Bonjour')
      expect(message.model_id).to eq('mistral-small-latest')
    end
  end
end
