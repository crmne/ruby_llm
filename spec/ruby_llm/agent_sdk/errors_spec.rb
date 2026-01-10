# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe 'RubyLLM::AgentSDK errors' do
  describe RubyLLM::AgentSDK::Error do
    it 'includes error_code' do
      error = described_class.new('test error', error_code: :test)
      expect(error.error_code).to eq(:test)
      expect(error.message).to eq('test error')
    end

    it 'converts to hash' do
      error = described_class.new('test', error_code: :test)
      expect(error.to_h).to eq({ code: :test, message: 'test' })
    end
  end

  describe RubyLLM::AgentSDK::CLINotFoundError do
    it 'has cli_not_found error code' do
      error = described_class.new
      expect(error.error_code).to eq(:cli_not_found)
    end
  end

  describe RubyLLM::AgentSDK::CLIConnectionError do
    it 'has connection_error error code' do
      error = described_class.new('Connection failed')
      expect(error.error_code).to eq(:connection_error)
    end

    it 'includes host and port' do
      error = described_class.new('Connection failed', host: 'localhost', port: 8080)
      expect(error.host).to eq('localhost')
      expect(error.port).to eq(8080)
    end

    it 'converts to hash with connection details' do
      error = described_class.new('Failed', host: 'localhost', port: 8080)
      hash = error.to_h

      expect(hash[:code]).to eq(:connection_error)
      expect(hash[:host]).to eq('localhost')
      expect(hash[:port]).to eq(8080)
    end
  end

  describe RubyLLM::AgentSDK::ProcessError do
    it 'includes exit_code and stderr' do
      error = described_class.new('Process failed', exit_code: 1, stderr: 'error output')
      expect(error.exit_code).to eq(1)
      expect(error.stderr).to eq('error output')
    end
  end

  describe RubyLLM::AgentSDK::JSONDecodeError do
    it 'includes line and original_error' do
      original = JSON::ParserError.new('unexpected token')
      error = described_class.new('Parse failed', line: '{"bad": json}', original_error: original)

      expect(error.line).to eq('{"bad": json}')
      expect(error.original_error).to eq(original)
    end
  end
end
