# frozen_string_literal: true

# Threads that reach the model registry before it has loaded, as the first
# requests after a deploy do, in a new process each run.
require_relative 'support/harness'

Benchmarks.configure

# Loads the registry code and reads the bundled file once, without loading the
# registry RubyLLM.models returns.
RubyLLM::Models.new
GC.start

def first_use(threads)
  Benchmarks.forked do
    started = Benchmarks.now
    registries = Array.new(threads) do
      Thread.new do
        models = RubyLLM.models
        models.find('gpt-4.1-mini')
        models
      end
    end.map(&:value)
    { 'ms' => (Benchmarks.now - started) * 1000, 'registries' => registries.map(&:object_id).uniq.size }
  end
end

Benchmarks.area('registry') do
  [1, 8].each do |threads|
    results = Array.new(Benchmarks.runs(10)) { first_use(threads) }
    name = "#{threads} #{threads == 1 ? 'thread' : 'threads'} on a cold registry"
    Benchmarks.record(name, :time, 'ms', results.map { |result| result['ms'] })
    Benchmarks.record(name, :registries, '', results.map { |result| result['registries'] })
  end
end
