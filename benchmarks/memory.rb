# frozen_string_literal: true

# How much a long chat keeps in memory: the heap a 40-turn conversation with
# a 256 KB image in its history still holds after a full GC, in a new process
# each run.
require 'objspace'
require_relative 'support/harness'
require_relative 'support/canned_adapter'
require_relative 'support/payloads'

Payloads = Benchmarks::Payloads
Canned = Benchmarks::CannedAdapter

Benchmarks.configure(faraday_adapter: Canned, openai_api_key: 'test')
Canned.route(%r{/responses\z}, json: Payloads.responses('Paris is the capital of France. ' * 20),
                               stream: Payloads.responses_stream(50))

IMAGE = File.join(Benchmarks.scratch('files'), 'image-256kb.png')
File.binwrite(IMAGE, Payloads.png(256 * 1024)) unless File.exist?(IMAGE)

def heap_mb
  3.times { GC.start(full_mark: true, immediate_sweep: true) }
  ObjectSpace.memsize_of_all / (1024.0 * 1024)
end

def converse(turns, stream:)
  block = stream ? :content.to_proc : nil
  chat = RubyLLM.chat(model: 'gpt-4.1-mini')
  chat.ask('What is in this image?', with: IMAGE, &block)
  (turns - 1).times { |turn| chat.ask("Question #{turn + 1}?", &block) }
  chat
end

Benchmarks.area('memory') do
  { 'replies' => false, 'streamed replies' => true }.each do |kind, stream|
    growth = Array.new(Benchmarks.runs(3)) do
      Benchmarks.forked do
        converse(2, stream:)
        baseline = heap_mb
        chat = converse(40, stream:)
        growth = heap_mb - baseline
        raise "Expected 80 messages, found #{chat.messages.size}" unless chat.messages.size == 80

        growth
      end
    end
    Benchmarks.record("40 turns with a 256 KB image, #{kind}", :heap_growth, 'MB', growth)
  end
end
