# frozen_string_literal: true

require 'yaml'

# Runs the Ruby examples of a docs page against stubbed providers, so the
# code a reader copies is the code the suite runs.
module DocExampleHelpers
  DOCS = File.expand_path('../../../docs', __dir__)
  MODELS = YAML.load_file(File.join(DOCS, '_config.yml')).fetch('models')

  def doc_page = raise(NotImplementedError, 'define doc_page')

  def doc_blocks
    File.read(File.join(DOCS, doc_page)).scan(/^```ruby\n(.*?)^```/m).flatten.map do |code|
      code.gsub(/\{\{ site\.models\.(\w+) \}\}/) { MODELS.fetch(Regexp.last_match(1)) }
    end
  end

  def doc_block(including)
    doc_blocks.find { |code| code.include?(including) } or raise "No Ruby example in #{doc_page} includes #{including}"
  end

  def doc_model(name) = MODELS.fetch(name)

  def evaluate(including, from: nil, **locals)
    code = doc_block(including)
    code = code[code.index(from)..] if from
    code.scan(/^class (\w+) < ([\w:]+)/) { |name, parent| stub_const(name, Class.new(Object.const_get(parent))) }
    scope = TOPLEVEL_BINDING.dup
    locals.each { |name, value| scope.local_variable_set(name, value) }
    path = File.join(DOCS, doc_page)
    line = File.read(path).lines.index { |text| text.include?(code.lines.first.strip) }.to_i + 1
    scope.eval(code, path, line)
  end

  def silently
    original = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original
  end

  def provider_requests = @provider_requests ||= []

  def stub_anthropic(*turns)
    stub_request(:post, 'https://api.anthropic.com/v1/messages').to_return do |request|
      body = JSON.parse(request.body)
      provider_requests << body
      turn = turns.shift or raise 'Unexpected Anthropic request'
      body['stream'] ? anthropic_stream(body['model'], turn) : anthropic_json(body['model'], turn)
    end
  end

  def stub_openai(*turns)
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return do |request|
      body = JSON.parse(request.body)
      provider_requests << body
      turn = turns.shift or raise 'Unexpected OpenAI request'
      body['stream'] ? openai_stream(body['model'], turn) : json_reply(openai_response(body['model'], turn))
    end
  end

  def tool_turn(name, **arguments) = { tool: name, arguments: }

  private

  def json_reply(body) = { body: JSON.generate(body), headers: { 'Content-Type' => 'application/json' } }

  def sse_reply(events)
    body = events.map { |event| "event: #{event[:type]}\ndata: #{JSON.generate(event)}\n\n" }.join
    { body:, headers: { 'Content-Type' => 'text/event-stream' } }
  end

  def anthropic_block(turn)
    return { type: 'text', text: turn } if turn.is_a?(String)

    { type: 'tool_use', id: "toolu_#{turn[:tool]}", name: turn[:tool], input: turn[:arguments] }
  end

  def anthropic_stop(turn) = turn.is_a?(String) ? 'end_turn' : 'tool_use'

  def anthropic_json(model, turn)
    json_reply(id: 'msg_doc', type: 'message', role: 'assistant', model:, content: [anthropic_block(turn)],
               stop_reason: anthropic_stop(turn), usage: { input_tokens: 20, output_tokens: 10 })
  end

  def anthropic_stream(model, turn)
    block = anthropic_block(turn)
    delta = if turn.is_a?(String)
              turn.scan(/.{1,8}/m).map { |text| { type: 'text_delta', text: } }
            else
              [{ type: 'input_json_delta', partial_json: JSON.generate(turn[:arguments]) }]
            end
    start = block[:type] == 'text' ? block.merge(text: '') : block.merge(input: {})
    message = { id: 'msg_doc', type: 'message', role: 'assistant', model:, content: [],
                usage: { input_tokens: 20, output_tokens: 1 } }
    sse_reply([
                { type: 'message_start', message: },
                { type: 'content_block_start', index: 0, content_block: start },
                *delta.map { |part| { type: 'content_block_delta', index: 0, delta: part } },
                { type: 'content_block_stop', index: 0 },
                { type: 'message_delta', delta: { stop_reason: anthropic_stop(turn) }, usage: { output_tokens: 10 } },
                { type: 'message_stop' }
              ])
  end

  def openai_item(turn)
    if turn.is_a?(String)
      { type: 'message', id: 'msg_doc', role: 'assistant', status: 'completed',
        content: [{ type: 'output_text', text: turn, annotations: [] }] }
    else
      { type: 'function_call', id: "fc_#{turn[:tool]}", call_id: "call_#{turn[:tool]}", name: turn[:tool],
        arguments: JSON.generate(turn[:arguments]), status: 'completed' }
    end
  end

  def openai_response(model, turn)
    { id: 'resp_doc', object: 'response', status: 'completed', model:, output: [openai_item(turn)],
      usage: { input_tokens: 20, output_tokens: 10, total_tokens: 30 } }
  end

  def openai_stream(model, turn)
    item = openai_item(turn)
    deltas = if turn.is_a?(String)
               turn.scan(/.{1,8}/m).map do |text|
                 { type: 'response.output_text.delta', output_index: 0, content_index: 0, delta: text }
               end
             else
               [{ type: 'response.function_call_arguments.delta', output_index: 0, delta: item[:arguments] }]
             end
    sse_reply([
                { type: 'response.created',
                  response: openai_response(model, turn).merge(status: 'in_progress', output: []) },
                { type: 'response.output_item.added', output_index: 0,
                  item: turn.is_a?(String) ? item : item.merge(arguments: '') },
                *deltas,
                { type: 'response.output_item.done', output_index: 0, item: },
                { type: 'response.completed', response: openai_response(model, turn) }
              ])
  end
end
