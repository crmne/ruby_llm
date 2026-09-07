# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::ChatCompletions::Batches do
  let(:protocol) { RubyLLM::Providers::Mistral.protocols.fetch(:chat_completions).allocate }

  describe '#mistral_batch_request' do
    it 'moves the model to the batch job and leaves the chat body model-free' do
      request = {
        custom_id: '0',
        model: 'mistral-small-latest',
        payload: {
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
    it 'sends embedding jobs to the embeddings endpoint' do
      connection = instance_double(RubyLLM::Transport::Connection)
      protocol.instance_variable_set(:@connection, connection)
      model = model_for(:mistral, :embedding)
      requests = [{ custom_id: '0', model: model, payload: { model: model, input: ['Ruby'] } }]
      response = instance_double(Faraday::Response, body: { 'id' => 'job_123', 'status' => 'QUEUED' })

      allow(connection).to receive(:post).with(
        'batch/jobs',
        { endpoint: '/v1/embeddings', model: model,
          requests: [{ custom_id: '0:array', body: { input: ['Ruby'] } }] },
        idempotent: false
      ).and_return(response)

      expect(protocol.create_batch(requests)).to include(id: 'job_123', completed: false)
      expect(connection).to have_received(:post)
    end

    it 'rejects mixed chat and embedding requests' do
      model = model_for(:mistral, :embedding)
      requests = [
        { model: model, payload: { input: 'Ruby' } },
        { model: model, payload: { messages: [] } }
      ]

      expect { protocol.create_batch(requests) }.to raise_error(RubyLLM::Error, /cannot mix/)
    end

    it 'rejects mixed-model jobs' do
      requests = [
        { model: 'mistral-small-latest', payload: {} },
        { model: 'mistral-large-latest', payload: {} }
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
        raw_status: 'SUCCESS',
        completed: true,
        request_count: 2,
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

  describe '#find_batch' do
    let(:connection) { instance_double(RubyLLM::Transport::Connection) }

    before do
      protocol.instance_variable_set(:@connection, connection)
      allow(protocol).to receive(:sleep)
    end

    it 'retries an initial missing job while a new submission becomes visible' do
      missing = RubyLLM::Error.new('No batch job matches', response: instance_double(Faraday::Response, status: 404))
      response = instance_double(Faraday::Response, body: { 'id' => 'job_123', 'status' => 'QUEUED' })
      attempts = 0
      allow(connection).to receive(:get).with('batch/jobs/job_123') do
        attempts += 1
        raise missing if attempts == 1

        response
      end

      expect(protocol.find_batch('job_123')).to include(id: 'job_123', completed: false)
      expect(connection).to have_received(:get).twice
      expect(protocol).to have_received(:sleep).with(0.5)
    end

    it 'raises when the job remains missing after bounded retries' do
      error = RubyLLM::Error.new('No batch job matches', response: instance_double(Faraday::Response, status: 404))
      allow(connection).to receive(:get).and_raise(error)

      expect { protocol.find_batch('job_123') }.to raise_error(error)
      expect(connection).to have_received(:get).exactly(3).times
    end

    it 'does not retry permission errors' do
      error = RubyLLM::ForbiddenError.new('Forbidden', response: instance_double(Faraday::Response, status: 403))
      allow(connection).to receive(:get).and_raise(error)

      expect { protocol.find_batch('job_123') }.to raise_error(error)
      expect(protocol).not_to have_received(:sleep)
    end
  end

  describe '#parse_batch_result' do
    it 'preserves scalar and one-element array embedding shapes after reloading a job' do
      body = { 'model' => model_for(:mistral, :embedding), 'data' => [{ 'embedding' => [0.1, 0.2] }],
               'usage' => { 'prompt_tokens' => 3 } }

      scalar_index, scalar = protocol.send(:parse_batch_result, 'custom_id' => '0', 'response' => { 'body' => body })
      array_line = { 'custom_id' => '1:array', 'response' => { 'body' => body } }
      array_index, array = protocol.send(:parse_batch_result, array_line)

      expect([scalar_index, array_index]).to eq([0, 1])
      expect(scalar.vectors).to eq([0.1, 0.2])
      expect(array.vectors).to eq([[0.1, 0.2]])
      expect(array.tokens.input).to eq(3)
    end

    it 'keeps a failed embedding request in its original slot' do
      result = protocol.send(:parse_batch_result, 'custom_id' => '2:array', 'error' => { 'message' => 'Invalid input' })

      expect(result).to eq([2, nil, :failed])
    end

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
      expect(message.model).to eq('mistral-small-latest')
    end
  end

  it 'submits, reloads, and cancels an embedding batch', :live do
    model = model_for(:mistral, :embedding)
    requests = ['Ruby', ['Rails']].map { |text| RubyLLM.embed_later(text, model:, provider: :mistral) }
    batch = RubyLLM.batch(requests)

    found = RubyLLM::Batch.find(batch.id, provider: :mistral)

    expect(found.id).to eq(batch.id)
    expect(found.request_counts['total']).to eq(2)
  ensure
    batch&.cancel unless batch&.complete?
  end
end
