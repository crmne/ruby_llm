# frozen_string_literal: true

require 'json'
require 'stringio'

module Benchmarks
  # Provider responses shaped like the recorded ones in spec/fixtures, built
  # from fixed text so every run parses the same bytes.
  module Payloads
    WORDS = %w[Ruby is a dynamic open source programming language with a focus on simplicity and
               productivity].freeze

    module_function

    def words(count)
      Array.new(count) { |index| " #{WORDS[index % WORDS.size]}" }
    end

    def event(data, name: nil, line_end: "\n")
      lines = name ? ["event: #{name}", "data: #{data}"] : ["data: #{data}"]
      "#{lines.join(line_end)}#{line_end}#{line_end}"
    end

    def json_event(data, name: nil, line_end: "\n")
      event(JSON.generate(data), name:, line_end:)
    end

    # OpenAI Responses API

    def responses(text)
      JSON.generate(id: 'resp_1', object: 'response', created_at: 1, status: 'completed', model: 'gpt-4.1-mini',
                    output: [{ id: 'msg_1', type: 'message', status: 'completed', role: 'assistant',
                               content: [{ type: 'output_text', text:, annotations: [] }] }],
                    usage: responses_usage(50))
    end

    def responses_tool_call(name, arguments, call_id:)
      JSON.generate(id: 'resp_2', object: 'response', created_at: 1, status: 'completed', model: 'gpt-4.1-mini',
                    output: [{ id: 'fc_1', type: 'function_call', status: 'completed', call_id:, name:,
                               arguments: JSON.generate(arguments) }],
                    usage: responses_usage(20))
    end

    def responses_usage(output_tokens)
      { input_tokens: 12, input_tokens_details: { cached_tokens: 0 }, output_tokens:,
        output_tokens_details: { reasoning_tokens: 0 }, total_tokens: output_tokens + 12 }
    end

    def responses_stream(count)
      response = { id: 'resp_1', object: 'response', created_at: 1, status: 'in_progress', model: 'gpt-4.1-mini',
                   output: [], usage: nil }
      item = { id: 'msg_1', type: 'message', status: 'in_progress', content: [], role: 'assistant' }
      events = [json_event({ type: 'response.created', response:, sequence_number: 0 }, name: 'response.created'),
                json_event({ type: 'response.output_item.added', output_index: 0, item:, sequence_number: 1 },
                           name: 'response.output_item.added')]
      words(count).each_with_index do |word, index|
        events << json_event({ type: 'response.output_text.delta', item_id: 'msg_1', output_index: 0,
                               content_index: 0, delta: word, logprobs: [], sequence_number: index + 2 },
                             name: 'response.output_text.delta')
      end
      done = response.merge(status: 'completed', usage: responses_usage(count),
                            output: [item.merge(status: 'completed',
                                                content: [{ type: 'output_text', text: words(count).join,
                                                            annotations: [] }])])
      events << json_event({ type: 'response.completed', response: done, sequence_number: count + 2 },
                           name: 'response.completed')
    end

    # Anthropic Messages API

    def anthropic(text)
      JSON.generate(id: 'msg_1', type: 'message', role: 'assistant', model: 'claude-haiku-4-5-20251001',
                    content: [{ type: 'text', text: }], stop_reason: 'end_turn', stop_sequence: nil,
                    usage: { input_tokens: 15, cache_creation_input_tokens: 0, cache_read_input_tokens: 0,
                             output_tokens: 50 })
    end

    def anthropic_stream(count)
      message = { id: 'msg_1', type: 'message', role: 'assistant', model: 'claude-haiku-4-5-20251001',
                  content: [], stop_reason: nil,
                  usage: { input_tokens: 15, cache_creation_input_tokens: 0, cache_read_input_tokens: 0,
                           output_tokens: 1 } }
      events = [json_event({ type: 'message_start', message: }, name: 'message_start'),
                json_event({ type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' } },
                           name: 'content_block_start')]
      words(count).each do |word|
        events << json_event({ type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: word } },
                             name: 'content_block_delta')
      end
      events << json_event({ type: 'content_block_stop', index: 0 }, name: 'content_block_stop')
      events << json_event({ type: 'message_delta', delta: { stop_reason: 'end_turn', stop_sequence: nil },
                             usage: { output_tokens: count } }, name: 'message_delta')
      events << json_event({ type: 'message_stop' }, name: 'message_stop')
    end

    # Chat Completions API

    def chat_completions(text, model: 'deepseek-v4-flash')
      JSON.generate(id: 'chatcmpl-1', object: 'chat.completion', created: 1, model:,
                    choices: [{ index: 0, message: { role: 'assistant', content: text }, finish_reason: 'stop' }],
                    usage: { prompt_tokens: 12, completion_tokens: 50, total_tokens: 62 })
    end

    def chat_completions_stream(deltas, model: 'deepseek-v4-flash', root: {})
      base = { id: 'chatcmpl-1', object: 'chat.completion.chunk', created: 1, model: }.merge(root)
      events = deltas.map do |delta|
        json_event(base.merge(choices: [{ index: 0, delta:, logprobs: nil, finish_reason: nil }]))
      end
      events << json_event(base.merge(choices: [{ index: 0, delta: {}, logprobs: nil, finish_reason: 'stop' }]))
      events << json_event(base.merge(choices: [], usage: { prompt_tokens: 12, completion_tokens: deltas.size,
                                                            total_tokens: deltas.size + 12 }))
      events << event('[DONE]')
    end

    def chat_completions_text_stream(count)
      chat_completions_stream([{ role: 'assistant', content: '' }] + words(count).map { |word| { content: word } })
    end

    # One event carrying +bytes+ of text, split into network reads of
    # +piece+ bytes.
    def chat_completions_large_event(bytes, piece:)
      stream = chat_completions_stream([{ role: 'assistant', content: 'A' * bytes }]).join.b
      (0...stream.bytesize).step(piece).map { |offset| stream.byteslice(offset, piece) }
    end

    # OpenRouter's reasoning_details, one fragment per chunk.
    def openrouter_reasoning_stream(count)
      deltas = words(count).map do |word|
        { reasoning: word, reasoning_details: [{ type: 'reasoning.text', text: word, index: 0 }] }
      end
      chat_completions_stream(deltas + [{ content: 'Done.' }], model: 'deepseek/deepseek-r1')
    end

    # Perplexity repeats every source on every chunk.
    def perplexity_stream(count, sources:)
      results = Array.new(sources) do |index|
        { title: "Source #{index}", url: "https://example.com/#{index}", date: '2026-01-01',
          snippet: "Snippet number #{index} " * 5 }
      end
      root = { citations: results.map { |result| result[:url] }, search_results: results }
      chat_completions_stream(words(count).map { |word| { content: word } }, model: 'sonar', root:)
    end

    # Gemini API, which ends its event lines with CRLF.

    def gemini(text)
      JSON.generate(candidates: [{ content: { role: 'model', parts: [{ text: }] }, finishReason: 'STOP', index: 0 }],
                    usageMetadata: { promptTokenCount: 8, candidatesTokenCount: 50, totalTokenCount: 58 },
                    modelVersion: 'gemini-2.5-flash', responseId: 'r1')
    end

    def gemini_stream(count)
      words(count).each_with_index.map do |word, index|
        last = index == count - 1
        candidate = { content: { parts: [{ text: word }], role: 'model' }, index: 0 }
        candidate[:finishReason] = 'STOP' if last
        json_event({ candidates: [candidate],
                     usageMetadata: { promptTokenCount: 8, candidatesTokenCount: index + 1,
                                      totalTokenCount: index + 9 },
                     modelVersion: 'gemini-2.5-flash', responseId: 'r1' }, line_end: "\r\n")
      end
    end

    # Bedrock Converse API

    def converse(text)
      JSON.generate(output: { message: { role: 'assistant', content: [{ text: }] } }, stopReason: 'end_turn',
                    usage: { inputTokens: 12, outputTokens: 50, totalTokens: 62 }, metrics: { latencyMs: 1 })
    end

    # ConverseStream frames in the AWS event stream encoding, with reasoning
    # deltas before the answer.
    def converse_reasoning_stream(count)
      require 'aws-eventstream'
      frames = [converse_frame('messageStart', role: 'assistant')]
      words(count).each do |word|
        frames << converse_frame('contentBlockDelta', contentBlockIndex: 0,
                                                      delta: { reasoningContent: { text: word } })
      end
      frames << converse_frame('contentBlockDelta', contentBlockIndex: 0,
                                                    delta: { reasoningContent: { signature: 'signature' } })
      frames << converse_frame('contentBlockStop', contentBlockIndex: 0)
      frames << converse_frame('contentBlockDelta', contentBlockIndex: 1, delta: { text: 'Done.' })
      frames << converse_frame('contentBlockStop', contentBlockIndex: 1)
      frames << converse_frame('messageStop', stopReason: 'end_turn')
      frames << converse_frame('metadata', usage: { inputTokens: 12, outputTokens: count, totalTokens: count + 12 },
                                           metrics: { latencyMs: 1 })
    end

    def converse_frame(type, payload)
      headers = { ':event-type' => type, ':content-type' => 'application/json', ':message-type' => 'event' }
      message = Aws::EventStream::Message.new(
        headers: headers.transform_values { |value| Aws::EventStream::HeaderValue.new(value:, type: 'string') },
        payload: StringIO.new(JSON.generate(payload))
      )
      Aws::EventStream::Encoder.new.encode(message)
    end

    # OpenAI embeddings of +count+ inputs with +dimensions+ values each.
    def embeddings(count, dimensions:)
      random = Random.new(1)
      data = Array.new(count) do |index|
        { object: 'embedding', index:, embedding: Array.new(dimensions) { (random.rand - 0.5).round(8) } }
      end
      JSON.generate(object: 'list', data:, model: 'text-embedding-3-small',
                    usage: { prompt_tokens: count * 10, total_tokens: count * 10 })
    end

    # Bytes that read as a PNG image, or a PDF, of the given size.
    def png(bytes)
      "\x89PNG\r\n\x1A\n".b + Random.new(1).bytes(bytes - 8)
    end

    def pdf(bytes)
      "%PDF-1.4\n".b + Random.new(1).bytes(bytes - 9)
    end
  end
end
