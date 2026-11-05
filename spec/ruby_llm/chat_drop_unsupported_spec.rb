# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'done', input_tokens: 1, output_tokens: 1)
  end

  def unsupported(parameter)
    RubyLLM::UnsupportedParameterError.new("Unsupported parameter: #{parameter}", parameter:)
  end

  describe 'UnsupportedParameterError from OpenAI, with bodies it returned' do
    def openai_error(message, param, code)
      { error: { message:, type: 'invalid_request_error', param:, code: } }
    end

    {
      chat_completions: {
        url: 'https://api.openai.com/v1/chat/completions',
        rejected: [
          ["Unsupported value: 'temperature' does not support 0.5 with this model. Only the default (1) value is " \
           'supported.', 'temperature', 'unsupported_value', :temperature],
          ["Unsupported parameter: 'top_p' is not supported with this model.", 'top_p', 'unsupported_parameter',
           'top_p'],
          ["Unsupported value: 'reasoning_effort' does not support 'xhigh' with this model. Supported values are: " \
           "'minimal', 'low', 'medium', and 'high'.", 'reasoning_effort', 'unsupported_value', :thinking],
          ["Unknown parameter: 'not_a_parameter'.", 'not_a_parameter', 'unknown_parameter', 'not_a_parameter']
        ]
      },
      responses: {
        url: 'https://api.openai.com/v1/responses',
        rejected: [
          ["Unsupported parameter: 'temperature' is not supported with this model.", 'temperature', nil, :temperature],
          ["Unsupported parameter: 'top_p' is not supported with this model.", 'top_p', nil, 'top_p'],
          ['logprobs are not supported with reasoning models.', 'top_logprobs', 'unsupported_parameter',
           'top_logprobs'],
          ["Unsupported value: 'xhigh' is not supported with the 'gpt-5-nano' model. Supported values are: " \
           "'minimal', 'low', 'medium', and 'high'.", 'reasoning.effort', 'unsupported_value', :thinking],
          ["Unknown parameter: 'stop'.", 'stop', 'unknown_parameter', 'stop']
        ]
      }
    }.each do |protocol, wire|
      context "with #{protocol}" do
        let(:chat) { RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol:) }

        wire[:rejected].each do |message, param, code, parameter|
          it "raises with #{parameter.inspect} for #{param} (code #{code.inspect})" do
            stub_request(:post, wire[:url]).to_return_json(status: 400, body: openai_error(message, param, code))

            expect { chat.ask('Hi') }.to raise_error(RubyLLM::UnsupportedParameterError) { |error|
              expect(error.parameter).to eq(parameter)
              expect(error).to be_a(RubyLLM::BadRequestError)
            }
          end
        end

        it 'raises a plain BadRequestError for other invalid requests' do
          stub_request(:post, wire[:url]).to_return_json(
            status: 400, body: openai_error('Invalid value.', 'messages', 'invalid_value')
          )

          expect { chat.ask('Hi') }.to raise_error(RubyLLM::BadRequestError) { |error|
            expect(error).not_to be_a(RubyLLM::UnsupportedParameterError)
          }
        end

        it 'raises a plain BadRequestError for an error with a parameter, no code, and other words' do
          stub_request(:post, wire[:url]).to_return_json(
            status: 400, body: openai_error('Temperature is out of range.', 'temperature', nil)
          )

          expect { chat.ask('Hi') }.to raise_error(RubyLLM::BadRequestError) { |error|
            expect(error).not_to be_a(RubyLLM::UnsupportedParameterError)
          }
        end
      end
    end

    it 'retries the Responses API without the temperature it rejected' do
      url = 'https://api.openai.com/v1/responses'
      answer = { id: 'resp_1', status: 'completed', model: model_for(:openai),
                 output: [{ type: 'message', role: 'assistant',
                            content: [{ type: 'output_text', text: 'done' }] }],
                 usage: { input_tokens: 1, output_tokens: 1 } }
      stub_request(:post, url).with(body: hash_including('temperature' => 0.2)).to_return_json(
        status: 400,
        body: openai_error("Unsupported parameter: 'temperature' is not supported with this model.", 'temperature', nil)
      )
      stub_request(:post, url).with { |request| !JSON.parse(request.body).key?('temperature') }
                              .to_return_json(body: answer)
      chat = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses)
                    .with_temperature(0.2).with_fallbacks(drop_unsupported: true)

      expect(chat.ask('Hi').content).to eq('done')
    end
  end

  describe 'with_fallbacks(drop_unsupported: true)' do
    let(:chat) { described_class.new(model: model_for(:openai)) }
    let(:sent) { [] }

    def respond_with(*outcomes)
      allow(chat.provider).to receive(:complete) do |_messages, **options|
        sent << options
        outcome = outcomes.shift
        outcome.is_a?(Exception) ? raise(outcome) : outcome
      end
    end

    it 'retries the same model once without the parameter, and reports it through after_fallback' do
      fallbacks = []
      chat.with_temperature(0.2).with_fallbacks(drop_unsupported: true).after_fallback { |f| fallbacks << f }
      respond_with(unsupported(:temperature), answer)

      expect(chat.ask('Hi').content).to eq('done')

      expect(sent.map { |options| options[:temperature] }).to eq([0.2, nil])
      expect(fallbacks.size).to eq(1)
      expect(fallbacks.first.dropped_parameter).to eq(:temperature)
      expect(fallbacks.first.to).to eq(fallbacks.first.from)
      expect(fallbacks.first).to be_succeeded
      expect(chat.temperature).to eq(0.2)
    end

    it 'drops thinking, the output cap, and citations' do
      chat.with_thinking(effort: :high).with_max_output_tokens(100).with_citations
          .with_fallbacks(drop_unsupported: true)
      respond_with(unsupported(:thinking), answer, unsupported(:max_output_tokens), answer,
                   unsupported(:citations), answer)

      3.times { chat.ask('Hi') }

      expect(sent[1][:thinking]).to be_nil
      expect(sent[3][:max_output_tokens]).to be_nil
      expect(sent[5][:citations]).to be(false)
      expect(chat.thinking).to be_truthy
      expect(chat.max_output_tokens).to eq(100)
    end

    it 'drops a provider option the provider names' do
      chat.with_provider_options(top_p: 0.5, seed: 1).with_fallbacks(drop_unsupported: true)
      respond_with(unsupported('top_p'), answer)

      chat.ask('Hi')

      expect(sent.last[:provider_options]).to eq(seed: 1)
      expect(chat.provider_options).to eq(top_p: 0.5, seed: 1)
    end

    it 'drops one parameter once, then goes on to the fallback models' do
      chat.with_temperature(0.2).with_fallbacks(model_for(:anthropic), drop_unsupported: true,
                                                                       on: [RubyLLM::BadRequestError])
      fallback_chat = nil
      chat.before_fallback { |fallback| fallback_chat = fallback.to }
      respond_with(unsupported(:temperature), unsupported(:max_output_tokens))
      allow(RubyLLM::Provider.resolve!(:anthropic)).to receive(:new).and_wrap_original do |original, *args|
        original.call(*args).tap { |provider| allow(provider).to receive(:complete).and_return(answer) }
      end

      expect(chat.ask('Hi').content).to eq('done')
      expect(sent.size).to eq(2)
      expect(fallback_chat.id).to eq(model_for(:anthropic))
    end

    it 'takes the option from an Agent macro, without fallback models' do
      agent = Class.new(RubyLLM::Agent) do
        temperature 0.2
        fallbacks drop_unsupported: true
      end.new
      outcomes = [unsupported(:temperature), answer]
      allow(agent.chat.provider).to receive(:complete) do |_messages, **options|
        sent << options
        outcome = outcomes.shift
        outcome.is_a?(Exception) ? raise(outcome) : outcome
      end

      expect(agent.ask('Hi').content).to eq('done')
      expect(sent.map { |options| options[:temperature] }).to eq([0.2, nil])
    end

    it 'raises without the option, so nothing is dropped silently' do
      chat.with_temperature(0.2)
      respond_with(unsupported(:temperature), answer)

      expect { chat.ask('Hi') }.to raise_error(RubyLLM::UnsupportedParameterError)
      expect(sent.size).to eq(1)
    end

    it 'raises when the parameter is nothing the chat set' do
      chat.with_fallbacks(drop_unsupported: true)
      respond_with(unsupported('logprobs'), answer)

      expect { chat.ask('Hi') }.to raise_error(RubyLLM::UnsupportedParameterError)
      expect(sent.size).to eq(1)
    end
  end
end
