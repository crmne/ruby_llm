# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/open_telemetry'

RSpec.describe RubyLLM::OpenTelemetry, :live do
  include_context 'with OpenTelemetry tracing'

  [%i[openai responses], %i[openai chat_completions], [:anthropic, nil], [:gemini, nil]].each do |slug, protocol|
    [false, true].each do |streaming|
      it "traces #{slug} #{protocol} #{streaming ? 'streaming' : 'buffered'} chats" do
        skip_without_cassette_or_key("#{slug.upcase}_API_KEY")
        model = model_for(slug, slug == :openai ? :temperature : :chat)
        RubyLLM.models.find(model, provider: slug)
        chat = RubyLLM.chat(model:, provider: slug, protocol:).with_max_output_tokens(128)
        observed = []
        callback = proc do |_chunk|
          observed << OpenTelemetry::Trace.current_span.context.span_id
          expect(spans).to be_empty
        end
        result = chat.ask('Reply with just the word hello.', &(callback if streaming))

        expect(result.content).not_to be_empty
        expect(spans.size).to eq(1)
        span = spans.first
        expect(span.name).to eq("chat #{chat.model.id}")
        expect(span.kind).to eq(:client)
        expect(span.attributes['gen_ai.response.model']).to eq(result.model)
        expect(span.attributes['gen_ai.usage.input_tokens']).to be_positive
        expect(span.attributes['gen_ai.usage.output_tokens']).to be_positive
        expect(span.status.code).to eq(OpenTelemetry::Trace::Status::UNSET)
        if streaming
          expect(observed).not_to be_empty
          expect(observed.uniq).to eq([span.span_id])
        end
      end
    end
  end

  it 'keeps simultaneous streaming chats and embeddings isolated in a fiber reactor' do
    skip_without_cassette_or_key('OPENAI_API_KEY')
    in_reactor do |task|
      tasks = Array.new(3) do |index|
        task.async do
          provider.tracer('application').in_span("request #{index}") do |parent|
            RubyLLM.workflow("branch #{index}") do
              chat = RubyLLM.chat(model: model_for(:openai, :temperature))
              chat.ask("Reply with just the number #{index}.") do |_chunk|
                expect(OpenTelemetry::Trace.current_span.context.trace_id).to eq(parent.context.trace_id)
              end
              RubyLLM.embed("Synthetic document #{index}", model: model_for(:openai, :embedding))
            end
          end
        end
      end
      tasks.each(&:wait)
    end

    expect(spans.size).to eq(12)
    3.times do |index|
      parent = spans.find { |span| span.name == "request #{index}" }
      workflow = spans.find { |span| span.name == "invoke_workflow branch #{index}" }
      children = spans.select { |span| span.parent_span_id == workflow.span_id }
      expect(workflow.parent_span_id).to eq(parent.span_id)
      expect(children.map { |span| span.attributes['gen_ai.operation.name'] }).to contain_exactly('chat', 'embeddings')
      expect(children.map(&:trace_id).uniq).to eq([parent.trace_id])
    end
    expect(OpenTelemetry::Trace.current_span.context).not_to be_valid
  end

  it 'traces structured output from an agent' do
    skip_without_cassette_or_key('OPENAI_API_KEY')
    chat_model = model_for(:openai, :temperature)
    agent = Class.new(RubyLLM::Agent) do
      model chat_model
      schema type: 'object', properties: { answer: { type: 'integer' } }, required: ['answer'],
             additionalProperties: false
    end

    result = agent.new.ask('What is six times seven?')

    expect(result.parsed).to eq('answer' => 42)
    expect(spans.size).to eq(1)
    expect(spans.first.attributes['gen_ai.output.type']).to eq('json')
  end

  it 'reports a provider validation error without leaking the error body' do
    skip_without_cassette_or_key('OPENAI_API_KEY')
    chat = RubyLLM.chat(model: model_for(:openai, :temperature)).with_max_output_tokens(-1)

    expect { chat.ask('hello') }.to raise_error(RubyLLM::BadRequestError)
    expect(spans.size).to eq(1)
    expect(spans.first.attributes['error.type']).to eq('RubyLLM::BadRequestError')
    expect(spans.first.status.code).to eq(OpenTelemetry::Trace::Status::ERROR)
    expect(spans.first.events).to be_nil
    expect(OpenTelemetry::Trace.current_span.context).not_to be_valid
  end

  %i[threads fibers].each do |mode|
    it "traces a real model tool round using #{mode}" do
      skip_without_cassette_or_key('OPENAI_API_KEY')
      embedding_model = model_for(:openai, :embedding)
      stub_const('TelemetryEcho', Class.new(RubyLLM::Tool) do
        description 'Echoes a label'
        parameter :label, type: :string

        define_method(:execute) do |label:|
          sleep 0.01
          RubyLLM.embed(label, model: embedding_model).vectors.size
          label
        end
      end)
      chat = RubyLLM.chat(model: model_for(:openai, :temperature), protocol: :chat_completions)
                    .with_tools(TelemetryEcho)
                    .with_tool_options(choice: :required, calls: :many, concurrency: mode)
      RubyLLM.workflow("tools #{mode}") do
        chat.ask_later('Call telemetry_echo twice in parallel with label alpha and label beta. ' \
                       'Both calls are independent.')
        generated = chat.generate
        expect(generated.tool_calls.size).to eq(2)
        chat.run_tools
        chat.with_tool_options(choice: :none).generate
      end

      workflow = spans.find { |span| span.name == "invoke_workflow tools #{mode}" }
      tools = spans.select { |span| span.name == 'execute_tool telemetry_echo' }
      embeddings = spans.select { |span| span.attributes['gen_ai.operation.name'] == 'embeddings' }
      expect(tools.size).to eq(2)
      expect(tools.map(&:parent_span_id)).to eq([workflow.span_id] * 2)
      expect(embeddings.map(&:parent_span_id)).to match_array(tools.map(&:span_id))
      expect(chat.messages.select(&:tool_result?).map(&:content)).to contain_exactly('alpha', 'beta')
      expect(OpenTelemetry::Trace.current_span.context).not_to be_valid
    end
  end
end
