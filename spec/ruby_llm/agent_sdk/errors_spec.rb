# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK do
  describe 'Error classes' do
    describe RubyLLM::AgentSDK::Error do
      it 'has an error code' do
        error = described_class.new('test', error_code: :test_error)
        expect(error.error_code).to eq(:test_error)
        expect(error.message).to eq('test')
      end

      it 'defaults error code to :unknown' do
        error = described_class.new('test')
        expect(error.error_code).to eq(:unknown)
      end

      it 'converts to hash' do
        error = described_class.new('test message', error_code: :test_error)
        expect(error.to_h).to eq({ code: :test_error, message: 'test message' })
      end
    end

    describe RubyLLM::AgentSDK::CLINotFoundError do
      it 'has correct error code' do
        error = described_class.new
        expect(error.error_code).to eq(:cli_not_found)
        expect(error.message).to eq('Claude CLI not found')
      end
    end

    describe RubyLLM::AgentSDK::ProcessError do
      it 'stores exit code and stderr' do
        error = described_class.new('failed', exit_code: 1, stderr: 'error output')
        expect(error.exit_code).to eq(1)
        expect(error.stderr).to eq('error output')
        expect(error.error_code).to eq(:process_error)
      end

      it 'includes exit code and stderr in hash' do
        error = described_class.new('failed', exit_code: 2, stderr: 'err')
        hash = error.to_h
        expect(hash[:exit_code]).to eq(2)
        expect(hash[:stderr]).to eq('err')
      end
    end

    describe RubyLLM::AgentSDK::TimeoutError do
      it 'has correct error code' do
        error = described_class.new
        expect(error.error_code).to eq(:timeout)
      end
    end

    describe RubyLLM::AgentSDK::PermissionDeniedError do
      it 'stores tool name and reason' do
        error = described_class.new('denied', tool_name: 'Bash', reason: 'dangerous')
        expect(error.tool_name).to eq('Bash')
        expect(error.reason).to eq('dangerous')
        expect(error.error_code).to eq(:permission_denied)
      end
    end
  end
end
