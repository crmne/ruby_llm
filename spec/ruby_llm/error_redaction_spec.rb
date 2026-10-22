# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Error do
  include_context 'with configured RubyLLM'

  let(:prompt) { 'Summarize the Q3 salaries of Ada Lovelace' }

  around do |example|
    original = RubyLLM.config.redact_error_messages
    example.run
  ensure
    RubyLLM.config.redact_error_messages = original
  end

  def refuse(status:, body:, headers: {})
    stub_request(:post, /.*/).to_return(status:, body: JSON.generate(body),
                                        headers: { 'Content-Type' => 'application/json' }.merge(headers))
  end

  def openai_refusal
    { error: { message: "Invalid content: '#{prompt}'", type: 'invalid_request_error', code: nil } }
  end

  def raised_by
    yield
  rescue RubyLLM::Error => e
    e
  end

  context 'without redaction' do
    it 'quotes what the provider wrote, as before' do
      refuse(status: 400, body: openai_refusal)

      error = raised_by { RubyLLM.chat(model: model_for(:openai), provider: :openai).ask(prompt) }

      expect(error).to be_a(RubyLLM::BadRequestError)
      expect(error.message).to eq("Invalid content: '#{prompt}'")
    end

    it 'follows its own message with what the provider wrote' do
      error = described_class.new('OpenAI Decisions returned an invalid judgment', provider_message: prompt)

      expect(error.message).to eq("OpenAI Decisions returned an invalid judgment: #{prompt}")
    end
  end

  context 'with redaction' do
    before { RubyLLM.config.redact_error_messages = true }

    it 'names the status, provider, and error code of an OpenAI refusal' do
      refuse(status: 400, body: openai_refusal)

      error = raised_by { RubyLLM.chat(model: model_for(:openai), provider: :openai).ask(prompt) }

      expect(error).to be_a(RubyLLM::BadRequestError)
      expect(error.message).to eq('openai returned HTTP 400 (invalid_request_error)')
      expect(error.provider).to eq('openai')
      expect(error.provider_message).to include(prompt)
      expect(error.response_body.to_s).to include(prompt)
    end

    it 'leaves the prompt out of a streamed refusal' do
      refuse(status: 400, body: openai_refusal)

      error = raised_by do
        RubyLLM.chat(model: model_for(:openai), provider: :openai).ask(prompt) { |_chunk| nil }
      end

      expect(error.message).to eq('openai returned HTTP 400 (invalid_request_error)')
    end

    it "names Anthropic's error type" do
      refuse(status: 400, body: { type: 'error', error: { type: 'invalid_request_error', message: prompt } })

      error = raised_by { RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic).ask(prompt) }

      expect(error.message).to eq('anthropic returned HTTP 400 (invalid_request_error)')
    end

    it "names Gemini's error status" do
      refuse(status: 400, body: { error: { code: 400, message: prompt, status: 'INVALID_ARGUMENT' } })

      error = raised_by { RubyLLM.chat(model: model_for(:gemini), provider: :gemini).ask(prompt) }

      expect(error.message).to eq('gemini returned HTTP 400 (INVALID_ARGUMENT)')
    end

    it 'still classifies the error by what the provider wrote' do
      refuse(status: 400, body: { error: { message: "This model's maximum context length is 8192 tokens: #{prompt}",
                                           type: 'invalid_request_error', code: 'context_length_exceeded' } })

      error = raised_by { RubyLLM.chat(model: model_for(:openai), provider: :openai).ask(prompt) }

      expect(error).to be_a(RubyLLM::ContextLengthExceededError)
      expect(error.message).to eq('openai returned HTTP 400 (context_length_exceeded)')
    end

    it 'keeps the request shape on the error' do
      refuse(status: 400, body: openai_refusal)

      error = raised_by { RubyLLM.chat(model: model_for(:openai), provider: :openai).ask(prompt) }

      expect(error.request_shape.turns.first.to_s).to eq("#0 user: text (#{prompt.length} chars)")
    end

    it 'leaves out an error code that reads like text' do
      refuse(status: 500, body: { error: { message: prompt, code: prompt } })

      error = raised_by { RubyLLM.chat(model: model_for(:openai), provider: :openai).ask(prompt) }

      expect(error.message).to eq('openai returned HTTP 500')
    end

    it 'leaves out a body that is not JSON' do
      stub_request(:post, /.*/).to_return(status: 502, body: "<html>#{prompt}</html>")

      error = raised_by { RubyLLM.chat(model: model_for(:openai), provider: :openai).ask(prompt) }

      expect(error.message).to eq('openai returned HTTP 502')
    end

    it "reads Bedrock's error type from its header" do
      response = Faraday::Response.new(status: 400, body: { 'message' => prompt },
                                       response_headers: { 'X-Amzn-ErrorType' =>
                                         'ValidationException:http://internal.amazon.com/coral/com.amazon.bedrock/' })

      error = described_class.new(response:, provider: 'bedrock', provider_message: prompt)

      expect(error.message).to eq('bedrock returned HTTP 400 (ValidationException)')
    end

    it 'keeps a message RubyLLM wrote and drops what the provider wrote after it' do
      error = described_class.new('OpenAI Decisions returned an invalid judgment', provider_message: prompt)

      expect(error.message).to eq('OpenAI Decisions returned an invalid judgment')
      expect(error.provider_message).to eq(prompt)
    end

    it 'leaves the prompt out of a failed Responses completion' do
      error = raised_by do
        RubyLLM::Protocols::Responses::Chat.parse_completion_body(
          { 'error' => { 'message' => prompt, 'code' => 'server_error' } },
          raw: Faraday::Response.new(status: 200,
                                     body: { 'error' => { 'message' => prompt,
                                                          'code' => 'server_error' } })
        )
      end

      expect(error.message).to eq('The provider returned HTTP 200 (server_error)')
    end

    it 'names the JSON-RPC code of an MCP error' do
      error = RubyLLM::MCP::Error.new(provider_message: "No issue matches #{prompt}", code: -32_602)

      expect(error.message).to eq('The MCP server returned an error (-32602)')
      expect(error.provider_message).to include(prompt)
    end

    it "names an MCP server's host when it answers over HTTP" do
      response = Faraday::Response.new(status: 500, body: '')
      error = RubyLLM::MCP::Error.new(provider_message: prompt, provider: 'mcp.example.com', code: -32_603, response:)

      expect(error.message).to eq('mcp.example.com returned HTTP 500 (-32603)')
    end

    it 'falls back to the default message without a response' do
      expect(RubyLLM::RateLimitError.new.message).to eq('Rate limit exceeded - please wait a moment')
    end
  end
end
