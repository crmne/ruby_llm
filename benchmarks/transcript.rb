# frozen_string_literal: true

# Rebuilding a persisted 100-message chat in the dummy app, as every request
# that loads a chat record does, with Rails' automatic_scope_inversing on (the
# default since Rails 7.0) and off (applications that predate it).
require_relative 'support/rails_app'

RailsApp = Benchmarks::RailsApp

def seed
  Benchmarks::CannedAdapter.route(%r{/responses\z},
                                  json: Benchmarks::Payloads.responses('Paris is the capital of France.'))
  Chat.create!(model: 'gpt-4.1-mini').tap do |chat|
    50.times { |index| chat.ask("Question #{index}?") }
  end
end

def measure_with_queries(name, teardown: nil, &block)
  block.call
  teardown&.call
  queries = RailsApp.queries(&block)
  teardown&.call
  Benchmarks.measure(name, runs: 15, warmup: 5, teardown:, &block)
  Benchmarks.record(name, :queries, '', [queries])
end

Benchmarks.area('transcript') do
  { 'on' => true, 'off' => false }.each do |setting, inversing|
    Benchmarks.isolated do
      RailsApp.boot(database: 'transcript', automatic_scope_inversing: inversing)
      chat = seed
      raise 'The chat should have 100 messages' unless chat.messages.count == 100

      label = "100 messages, automatic_scope_inversing #{setting}"
      measure_with_queries("Chat.find + to_llm, #{label}") { Chat.find(chat.id).to_llm }
      measure_with_queries("Chat.find + ask, #{label}", teardown: RailsApp.forget_new_rows) do
        Chat.find(chat.id).ask('And the next one?')
      end
    end
  end
end
