# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Responses do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::OpenAI.new(RubyLLM.config) }
  let(:model) { RubyLLM.models.find(model_for(:openai), provider: :openai) }
  let(:protocol) { provider.protocols.fetch(:responses).new(provider, model) }

  it 'returns the provider count through the registered Responses protocol' do
    response = instance_double(Faraday::Response, body: { 'object' => 'response.input_tokens', 'input_tokens' => 42 })
    allow(provider.connection).to receive(:post).and_return(response)
    messages = [RubyLLM::Message.new(role: :user, content: 'Hello')]

    expect(provider.count_tokens(messages, model: model)).to eq(42)
    expect(provider.connection).to have_received(:post).with(
      'responses/input_tokens', { model: model.id, input: [{ role: 'user', content: 'Hello' }] }
    )
  end

  it 'counts instructions, function tools, schemas and reasoning without generation-only options' do
    tool = instance_double(RubyLLM::Tool, name: 'weather', description: 'Looks up weather',
                                          parameters_schema: { type: 'object' }, provider_options: {})
    schema = { name: 'answer', schema: { type: 'object', properties: { answer: { type: 'string' } } }, strict: true }
    messages = [RubyLLM::Message.new(role: :system, content: 'Be concise.'),
                RubyLLM::Message.new(role: :user, content: 'Weather?')]

    payload = protocol.send(
      :render_count_tokens_payload, messages, tools: { weather: tool }, model: model,
                                              tool_prefs: { choice: :required, calls: :one }, schema: schema,
                                              thinking: RubyLLM::Thinking::Config.new(effort: :low), caching: { key: 'weather' }
    )

    expect(payload).to include(
      model: model.id, instructions: 'Be concise.', input: [{ role: 'user', content: 'Weather?' }],
      tools: [hash_including(type: 'function', name: 'weather')],
      tool_choice: :required, parallel_tool_calls: false, reasoning: { effort: 'low' },
      text: { format: { type: 'json_schema', name: 'answer', schema: schema[:schema], strict: true } }
    )
    expect(payload.keys).to contain_exactly(
      :model, :input, :instructions, :tools, :tool_choice, :parallel_tool_calls, :reasoning, :text
    )
  end

  it 'keeps file references and image inputs in the counting payload' do
    file = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'proposal.pdf', mime_type: 'application/pdf')
    image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__))
    message = RubyLLM::Message.new(role: :user, content: 'Compare these', attachments: [file, image])

    payload = protocol.send(:render_count_tokens_payload, [message], tools: {}, model: model)

    expect(payload[:input].first[:content]).to contain_exactly(
      { type: 'input_text', text: 'Compare these' },
      { type: 'input_file', file_id: 'file_123' },
      hash_including(type: 'input_image', image_url: a_string_starting_with('data:image/png;base64,'))
    )
  end

  [RubyLLM::Providers::Azure::Responses, RubyLLM::Providers::XAI::Responses,
   RubyLLM::Providers::DeepSeek::Responses, RubyLLM::Providers::Bedrock::Mantle::Responses].each do |dialect|
    it "does not enable OpenAI token counting on #{dialect}" do
      connection = instance_double(RubyLLM::Transport::Connection)
      other_provider = instance_double(
        RubyLLM::Providers::Bedrock, name: 'Other provider', config: RubyLLM.config,
                                     connection: connection, mantle_connection: connection
      )
      other_protocol = dialect.new(other_provider, model)
      allow(connection).to receive(:post)

      expect { other_protocol.count_tokens([], tools: {}) }
        .to raise_error(RubyLLM::Error, 'Other provider doesn\'t support token counting')
      expect(connection).not_to have_received(:post)
    end
  end
end
