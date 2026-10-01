# frozen_string_literal: true

# The work RubyLLM does around each request, through a canned adapter: a chat
# that resends its history, tools rendered on every request, a large response
# body, and a Bedrock request that carries an image.
require_relative 'support/harness'
require_relative 'support/canned_adapter'
require_relative 'support/payloads'

Payloads = Benchmarks::Payloads
Canned = Benchmarks::CannedAdapter

Benchmarks.configure(
  faraday_adapter: Canned, openai_api_key: 'test', anthropic_api_key: 'test', deepseek_api_key: 'test',
  bedrock_api_key: 'test', bedrock_secret_key: 'test', bedrock_region: 'us-east-1'
)

ANSWER = 'Paris is the capital of France.'
Canned.route(%r{/responses\z}, json: Payloads.responses(ANSWER))
Canned.route(%r{/messages\z}, json: Payloads.anthropic(ANSWER))
Canned.route(%r{/chat/completions\z}, json: Payloads.chat_completions(ANSWER))
Canned.route(%r{/converse\z}, json: Payloads.converse(ANSWER))

PROTOCOLS = {
  'Responses' => { model: 'gpt-4.1-mini', provider: :openai },
  'Anthropic' => { model: 'claude-haiku-4-5', provider: :anthropic },
  'Chat Completions' => { model: 'deepseek-v4-flash', provider: :deepseek, protocol: :chat_completions },
  'Bedrock Converse' => { model: 'claude-haiku-4-5', provider: :bedrock }
}.freeze

TOOLS = Array.new(10) do |index|
  tool = Class.new(RubyLLM::Tool) do
    description "Looks up the forecast for a city from weather service #{index}"
    parameter :city, description: 'City name'

    def execute(city:) = "Sunny in #{city}"
  end
  Object.const_set(:"BenchmarkForecast#{index}", tool)
end

def history_chat(chat_options, messages)
  chat = RubyLLM.chat(**chat_options).with_instructions('You are a helpful assistant who answers concisely.')
  (messages / 2).times do |index|
    chat.add_message(role: :user, content: "Question #{index}: what is the capital of country #{index}?")
    chat.add_message(role: :assistant, content: "The capital of country #{index} is city #{index}. " * 5)
  end
  chat
end

# Asks once more on a chat with history, then forgets the exchange, so every
# call sends the same transcript.
def ask_again(chat)
  chat.ask('And the next one?')
  chat.messages.pop(2)
end

def history(messages)
  PROTOCOLS.each do |protocol, chat_options|
    chat = history_chat(chat_options, messages)
    Benchmarks.measure("#{protocol}, ask with #{messages} messages of history", iterations: 20, warmup: 10) do
      ask_again(chat)
    end
  end
end

def tools
  Canned.route(%r{/responses\z}) do |request|
    if request.body.include?('function_call_output')
      Payloads.responses('It is sunny in Paris.')
    else
      Payloads.responses_tool_call('benchmark_forecast3', { city: 'Paris' }, call_id: 'call_1')
    end
  end
  ask = -> { RubyLLM.chat(model: 'gpt-4.1-mini').with_tools(*TOOLS).ask('What is the weather in Paris?') }
  raise 'The tool round did not finish' unless ask.call.content == 'It is sunny in Paris.'

  Benchmarks.measure('Responses, ask with 10 tools and one tool call', iterations: 20, warmup: 10, &ask)
end

def embeddings
  Canned.route(%r{/embeddings\z}, json: Payloads.embeddings(100, dimensions: 1536))
  inputs = Array.new(100) { |index| "Input text number #{index}" }
  Benchmarks.measure('Embeddings, 100 inputs of 1536 dimensions (2.4 MB response)', iterations: 5, warmup: 3) do
    RubyLLM.embed(inputs, model: 'text-embedding-3-small')
  end
end

def image_history
  image = File.join(Benchmarks.scratch('files'), 'image-2mb.png')
  File.binwrite(image, Payloads.png(2 * 1024 * 1024)) unless File.exist?(image)
  chat = RubyLLM.chat(**PROTOCOLS.fetch('Bedrock Converse'))
  chat.ask('Describe this image.', with: image)
  minor_gcs = { 'minor GCs per 100 asks' => -> { GC.stat(:minor_gc_count) } }
  Benchmarks.measure('Bedrock Converse, ask with a 2 MB image in history', runs: 5, warmup: 10, iterations: 100,
                                                                           counters: minor_gcs) do
    ask_again(chat)
  end
end

Benchmarks.area('requests') do
  history(20)
  history(200)
  tools
  embeddings
  image_history
end
