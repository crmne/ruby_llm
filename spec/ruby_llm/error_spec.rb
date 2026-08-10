# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Error do
  describe '#initialize' do
    context 'with a message' do
      it 'uses the message and leaves response nil' do
        error = described_class.new('something went wrong')
        expect(error.message).to eq('something went wrong')
        expect(error.response).to be_nil
      end

      it 'works with the standard raise convention' do
        expect { raise described_class, 'something went wrong' }
          .to raise_error(described_class, 'something went wrong')
      end
    end

    context 'with a message and a response' do
      let(:response) { Struct.new(:status, :body).new(500, '{"error":"server error"}') }

      it 'stores the response' do
        error = described_class.new('server error', response: response)
        expect(error.response).to eq(response)
      end

      it 'uses the provided message' do
        error = described_class.new('server error', response: response)
        expect(error.message).to eq('server error')
      end
    end

    context 'with a response only' do
      let(:response) { Struct.new(:status, :body).new(500, 'raw body') }

      it 'falls back to the response body for the message' do
        error = described_class.new(response: response)
        expect(error.message).to eq('raw body')
      end
    end

    context 'with no arguments' do
      it 'works without raising' do
        error = described_class.new
        expect(error.response).to be_nil
        expect(error.message).to eq('RubyLLM::Error')
      end
    end
  end

  describe 'subclasses' do
    it 'accepts a plain message' do
      error = RubyLLM::BadRequestError.new('bad request')
      expect(error.message).to eq('bad request')
      expect(error.response).to be_nil
    end

    it 'keeps local setup and programming errors outside RubyLLM::Error' do
      local_errors = [
        RubyLLM::ConfigurationError,
        RubyLLM::PromptNotFoundError,
        RubyLLM::InvalidRoleError,
        RubyLLM::InvalidToolChoiceError,
        RubyLLM::ModelNotFoundError
      ]

      expect(local_errors).to all(be < StandardError)
      expect(local_errors.any? { |error_class| error_class < described_class }).to be(false)
    end
  end

  describe RubyLLM::ToolCallParseError do
    it 'stores the finish reason when available' do
      error = described_class.new(finish_reason: 'length')

      expect(error.finish_reason).to eq('length')
      expect(error.message).to include('finish_reason: length')
    end
  end

  describe RubyLLM::UnsupportedAttachmentError do
    it 'is a RubyLLM operation error' do
      error = described_class.new('audio/wav')

      expect(error).to be_a(RubyLLM::Error)
      expect(error.response).to be_nil
    end

    it 'uses a simple standard message with the unsupported type and guidance' do
      error = described_class.new('application/vnd.openxmlformats-officedocument.wordprocessingml.document')

      expect(error.message).to eq(
        'Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document. ' \
        'Consider using a model that supports this attachment type.'
      )
    end

    it 'omits the type when none is provided' do
      error = described_class.new

      expect(error.message).to eq(
        'Unsupported attachment type. Consider using a model that supports this attachment type.'
      )
    end
  end

  describe 'default messages' do
    {
      RubyLLM::BadRequestError => 'Invalid request - please check your input',
      RubyLLM::ForbiddenError => 'Forbidden - you do not have permission to access this resource',
      RubyLLM::ContextLengthExceededError => 'Context length exceeded',
      RubyLLM::OverloadedError => 'Service overloaded - please try again later',
      RubyLLM::PaymentRequiredError => 'Payment required - please top up your account',
      RubyLLM::RateLimitError => 'Rate limit exceeded - please wait a moment',
      RubyLLM::ServerError => 'API server error - please try again',
      RubyLLM::ServiceUnavailableError => 'API server unavailable - please try again later',
      RubyLLM::UnauthorizedError => 'Invalid API key - check your credentials'
    }.each do |error_class, message|
      it "explains #{error_class} when the provider says nothing" do
        expect(error_class.default_message).to eq(message)
        expect(error_class.new.message).to eq(message)
      end
    end
  end

  describe 'RubyLLM::UnsupportedAttachmentError messages' do
    it 'names the type when there is one' do
      expect(RubyLLM::UnsupportedAttachmentError.new('application/zip').message).to start_with(
        'Unsupported attachment type: application/zip.'
      )
    end

    it 'still guides without a type' do
      expect(RubyLLM::UnsupportedAttachmentError.new.message).to start_with('Unsupported attachment type.')
    end
  end
end
