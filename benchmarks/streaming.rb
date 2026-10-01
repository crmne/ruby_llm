# frozen_string_literal: true

# Streams canned responses through Chat#ask with a block: text deltas in each
# protocol, one large event split across network reads, long reasoning, and
# citations a provider repeats on every chunk.
require_relative 'support/harness'
require_relative 'support/canned_adapter'
require_relative 'support/payloads'

Payloads = Benchmarks::Payloads
Canned = Benchmarks::CannedAdapter

Benchmarks.configure(
  faraday_adapter: Canned, openai_api_key: 'test', anthropic_api_key: 'test', deepseek_api_key: 'test',
  gemini_api_key: 'test', openrouter_api_key: 'test', perplexity_api_key: 'test',
  bedrock_api_key: 'test', bedrock_secret_key: 'test', bedrock_region: 'us-east-1'
)

PROTOCOLS = {
  'Responses' => [{ model: 'gpt-4.1-mini', provider: :openai }, %r{/responses\z}, :responses_stream],
  'Anthropic' => [{ model: 'claude-haiku-4-5', provider: :anthropic }, %r{/messages\z}, :anthropic_stream],
  'Chat Completions' => [{ model: 'deepseek-v4-flash', provider: :deepseek, protocol: :chat_completions },
                         %r{/chat/completions\z}, :chat_completions_text_stream],
  'Gemini' => [{ model: 'gemini-2.5-flash', provider: :gemini }, /:streamGenerateContent\z/, :gemini_stream]
}.freeze
DEEPSEEK = { model: 'deepseek-v4-flash', provider: :deepseek, protocol: :chat_completions }.freeze
BEDROCK = { model: 'claude-haiku-4-5', provider: :bedrock }.freeze
OPENROUTER = { model: 'deepseek/deepseek-r1', provider: :openrouter, protocol: :chat_completions }.freeze
PERPLEXITY = { model: 'sonar', provider: :perplexity, protocol: :chat_completions }.freeze

def stream(chat_options)
  RubyLLM.chat(**chat_options).ask('Hello', &:content)
end

# Streams once and checks the answer, so a payload the version under test
# cannot parse fails loudly instead of timing an error path.
def stream_case(name, chat_options, pattern, pieces, runs:, warmup:, &check)
  Canned.reset
  Canned.route(pattern, stream: pieces)
  message = stream(chat_options)
  raise "#{name}: unexpected answer #{message.content.to_s[0, 80].inspect}" unless check.call(message)

  Benchmarks.measure(name, runs:, warmup:) { stream(chat_options) }
end

def text_deltas(count)
  text = Payloads.words(count).join
  long = count > 1000
  PROTOCOLS.each do |protocol, (chat_options, pattern, builder)|
    stream_case("#{protocol}, #{count} text deltas", chat_options, pattern, Payloads.public_send(builder, count),
                runs: long ? 5 : 15, warmup: long ? 1 : 3) { |message| message.content == text }
  end
end

def large_event
  bytes = 2 * 1024 * 1024
  stream_case('Chat Completions, one 2 MB event in 16 KB reads', DEEPSEEK, %r{/chat/completions\z},
              Payloads.chat_completions_large_event(bytes, piece: 16 * 1024), runs: 10, warmup: 2) do |message|
    message.content.bytesize == bytes
  end
end

def reasoning(count)
  thinking = Payloads.words(count).join
  answered = ->(message) { message.content == 'Done.' && message.thinking&.text == thinking }
  stream_case("Bedrock Converse, #{count} reasoning deltas", BEDROCK, %r{/converse-stream\z},
              Payloads.converse_reasoning_stream(count), runs: 5, warmup: 1, &answered)
  stream_case("OpenRouter, #{count} reasoning fragments", OPENROUTER, %r{/chat/completions\z},
              Payloads.openrouter_reasoning_stream(count), runs: 5, warmup: 1, &answered)
end

def citations(sources)
  stream_case("Perplexity, 500 chunks citing #{sources} sources each", PERPLEXITY, %r{/chat/completions\z},
              Payloads.perplexity_stream(500, sources:), runs: 10, warmup: 2) do |message|
    message.citations.size == sources
  end
end

Benchmarks.area('streaming') do
  text_deltas(500)
  text_deltas(20_000)
  large_event
  reasoning(5000)
  reasoning(20_000)
  citations(10)
  citations(20)
end
