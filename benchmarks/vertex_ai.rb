# frozen_string_literal: true

# Vertex AI calls authenticated with a service account key, against a token
# endpoint that answers after BENCH_TOKEN_LATENCY_MS (50 by default), the way
# Google's OAuth endpoint answers over the network. Each run is a new process.
require 'googleauth'
require 'openssl'
require_relative 'support/harness'
require_relative 'support/canned_adapter'
require_relative 'support/payloads'

Canned = Benchmarks::CannedAdapter
TOKEN_LATENCY = Integer(ENV.fetch('BENCH_TOKEN_LATENCY_MS', 50)) / 1000.0

# Answers googleauth's token requests, which go through Faraday's default
# connection, and counts them.
class TokenEndpoint < Faraday::Adapter
  class << self
    attr_accessor :requests
  end
  self.requests = 0

  def call(env)
    super
    sleep(TOKEN_LATENCY)
    self.class.requests += 1
    body = JSON.generate(access_token: "token-#{self.class.requests}", expires_in: 3600, token_type: 'Bearer')
    save_response(env, 200, body, { 'Content-Type' => 'application/json' })
    @app.call(env)
  end
end
Faraday.default_connection = Faraday.new { |faraday| faraday.adapter(TokenEndpoint) }

key = OpenSSL::PKey::RSA.new(2048)
service_account = JSON.generate(
  type: 'service_account', project_id: 'benchmark-project', private_key_id: 'benchmark',
  private_key: key.to_pem, client_email: 'benchmark@benchmark-project.iam.gserviceaccount.com', client_id: '1'
)
Benchmarks.configure(faraday_adapter: Canned, vertexai_project_id: 'benchmark-project',
                     vertexai_location: 'us-central1', vertexai_service_account_key: service_account)
Canned.route(/:generateContent\z/, json: Benchmarks::Payloads.gemini('Paris is the capital of France.'))

def ask
  RubyLLM.chat(model: 'gemini-2.5-flash', provider: :vertexai).ask('What is the capital of France?')
end

def calls(threads:, per_thread:)
  results = Array.new(Benchmarks.runs(5)) do
    Benchmarks.forked do
      TokenEndpoint.requests = 0
      started = Benchmarks.now
      Array.new(threads) { Thread.new { per_thread.times { ask } } }.each(&:join)
      { 'ms' => (Benchmarks.now - started) * 1000 / (threads * per_thread), 'tokens' => TokenEndpoint.requests }
    end
  end
  name = threads == 1 ? "#{per_thread} calls" : "#{threads} threads, #{per_thread} calls each"
  Benchmarks.record(name, :time_per_call, 'ms', results.map { |result| result['ms'] })
  Benchmarks.record(name, :token_requests, '', results.map { |result| result['tokens'] })
end

Benchmarks.area('vertex_ai') do
  ask
  calls(threads: 1, per_thread: 20)
  calls(threads: 4, per_thread: 5)
end
