# frozen_string_literal: true

# Chat calls to a loopback HTTPS server through the default adapter and the
# keep-alive adapters the connection guide recommends: how many TLS
# handshakes 20 calls cost, and how long each call takes. Each run is a new
# process; the server runs in this one and counts handshakes.
require 'async'
require 'async/http/faraday'
require 'faraday/net_http_persistent'
require_relative 'support/harness'
require_relative 'support/payloads'
require_relative 'support/tls_server'

Warning[:experimental] = false
CALLS = 20
SERVER = Benchmarks::TLSServer.new(Benchmarks::Payloads.responses('Pong.'))
Benchmarks.configure(openai_api_key: 'test', openai_api_base: "#{SERVER.url}/v1", request_timeout: 30)

def ask(context = RubyLLM)
  context.chat(model: 'gpt-4.1-nano').ask('Ping?')
end

def one_thread(calls) = calls.times { ask }
def four_threads(calls) = Array.new(4) { Thread.new { (calls / 4).times { ask } } }.each(&:join)

# Each tenant brings its own API key, as a multi-tenant application's
# contexts do.
def tenants(calls)
  contexts = Array.new(4) { |index| RubyLLM.context { |config| config.openai_api_key = "tenant-#{index}" } }
  calls.times { |index| ask(contexts[index % contexts.size]) }
end

def concurrent_tasks(calls)
  Sync { |task| (calls / 5).times { Array.new(5) { task.async { ask } }.each(&:wait) } }
end

SCENARIOS = {
  'one thread' => method(:one_thread),
  '4 threads' => method(:four_threads),
  '4 tenant contexts' => method(:tenants),
  'Async reactor, one task' => ->(calls) { Sync { one_thread(calls) } },
  'Async reactor, 5 concurrent tasks' => method(:concurrent_tasks),
  'Async reactor, 4 tenant contexts' => ->(calls) { Sync { tenants(calls) } }
}.freeze

MATRIX = {
  net_http: ['one thread', '4 threads', '4 tenant contexts', 'Async reactor, one task'],
  net_http_persistent: ['one thread', '4 threads', '4 tenant contexts'],
  async_http: ['one thread', 'Async reactor, one task', 'Async reactor, 5 concurrent tasks',
               'Async reactor, 4 tenant contexts']
}.freeze

Benchmarks.area('connections') do
  MATRIX.each do |adapter, scenarios|
    RubyLLM.config.faraday_adapter = adapter
    scenarios.each do |scenario|
      run = SCENARIOS.fetch(scenario)
      run.call(4)
      times = []
      handshakes = []
      Benchmarks.runs(5).times do
        before = SERVER.handshakes
        times << Benchmarks.forked do
          started = Benchmarks.now
          run.call(CALLS)
          (Benchmarks.now - started) * 1000 / CALLS
        end
        handshakes << (SERVER.handshakes - before)
      end
      name = "#{adapter}, #{scenario}"
      Benchmarks.record(name, :time_per_call, 'ms', times)
      Benchmarks.record(name, :"handshakes_per_#{CALLS}_calls", '', handshakes)
    end
  end
ensure
  SERVER.close
end
