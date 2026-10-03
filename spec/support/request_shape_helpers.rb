# frozen_string_literal: true

# Request shapes as errors build them: from a refused request, or from a
# rendered payload. The conversations here carry a secret in every value,
# so a spec can check that a shape shows none of them.
module RequestShapeHelpers
  SECRET_IMAGE = File.expand_path('../fixtures/ruby.png', __dir__)
  SECRET_DATA = Base64.strict_encode64(File.binread(SECRET_IMAGE))[0, 32]
  REFUSAL = {
    error: { code: 400, message: 'Request contains an invalid argument.', status: 'INVALID_ARGUMENT' }
  }.freeze

  def request_shape_for(protocol, payload)
    protocol.request_shape(payload)
  end

  def refuse_requests(status: 400)
    stub_request(:post, /.*/).to_return(status:, body: JSON.generate(REFUSAL),
                                        headers: { 'Content-Type' => 'application/json' })
  end

  def refused_request_shape(chat, &)
    refuse_requests
    chat.complete(&)
  rescue RubyLLM::BadRequestError => e
    e.request_shape
  end

  def secret_chat(provider:, model:, protocol: nil)
    chat = RubyLLM.chat(model:, provider:, protocol:).with_instructions('secret instructions').with_tools(lookup_tool)
    secret_conversation(provider, model).each { |message| chat.add_message(message) }
    chat
  end

  # Everything a shape can print: its text, its Hash, and the inspection of
  # the shape and everything in it.
  def everything_shown(shape)
    pieces = [shape, *shape.turns, *shape.instructions, *shape.turns.flat_map(&:parts), *shape.tool_rounds,
              *shape.problems]
    [shape.to_s, JSON.generate(shape.to_h), *pieces.map(&:inspect), *shape.problems.map(&:to_s)].join("\n")
  end

  def expect_no_secrets(shape)
    shown = everything_shown(shape)

    expect(shown).not_to match(/secret|example\.com/i)
    expect(shown).not_to include(SECRET_DATA)
  end

  private

  def lookup_tool
    Class.new(RubyLLM::Tool) do
      description 'Looks things up'
      parameter :query, description: 'What to look up'
      define_method(:name) { 'lookup' }
      define_method(:execute) { |query:| query }
    end
  end

  def secret_conversation(provider, model)
    entry = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider: provider.to_s, model:, status: :succeeded)
    produced = { usage_entries: [entry], model: }
    call = RubyLLM::ToolCall.new(id: 'secret-call-1', name: 'lookup', arguments: { 'query' => 'secret argument' },
                                 thought_signature: 'secret-call-signature')
    [
      RubyLLM::Message.new(role: :user, content: 'secret question', attachments: [SECRET_IMAGE]),
      RubyLLM::Message.new(role: :assistant, content: nil, tool_calls: { 'secret-call-1' => call }, **produced,
                           thinking: RubyLLM::Thinking.build(text: 'secret thought', signature: 'secret-signature')),
      RubyLLM::Message.new(role: :tool, content: 'secret result', tool_call_id: 'secret-call-1'),
      RubyLLM::Message.new(role: :assistant, content: 'secret answer', **produced,
                           thinking: RubyLLM::Thinking.build(text: 'secret plan', signature: 'secret-signature')),
      RubyLLM::Message.new(role: :user, content: 'secret follow-up')
    ]
  end
end

RSpec.configure do |config|
  config.include RequestShapeHelpers
end
