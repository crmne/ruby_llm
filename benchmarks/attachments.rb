# frozen_string_literal: true

# A persisted chat with ten 1 MB images in Active Storage, on the disk
# service: what loading it to check for pending approvals downloads, and what
# asking it again downloads.
require 'stringio'
require_relative 'support/rails_app'

RailsApp = Benchmarks::RailsApp

def seed
  Benchmarks::CannedAdapter.route(%r{/responses\z}, json: Benchmarks::Payloads.responses('A red square.'))
  image = Benchmarks::Payloads.png(1024 * 1024)
  Chat.create!(model: 'gpt-4.1-mini').tap do |chat|
    10.times do |index|
      message = chat.messages.create!(role: 'user', content: "What is in picture #{index}?")
      message.attachments.attach(io: StringIO.new(image), filename: "picture-#{index}.png", content_type: 'image/png')
      chat.messages.create!(role: 'assistant', content: "Picture #{index} shows a red square.")
    end
  end
end

def measure_with_downloads(name, teardown: nil, &)
  downloads = RailsApp.downloads(&)
  teardown&.call
  Benchmarks.measure(name, runs: 15, warmup: 3, teardown:, &)
  Benchmarks.record(name, :downloads, '', [downloads])
end

Benchmarks.area('attachments') do
  Benchmarks.isolated do
    RailsApp.boot(database: 'attachments')
    chat = seed
    measure_with_downloads('Chat.find + awaiting_approval?, 10 images of 1 MB') do
      Chat.find(chat.id).awaiting_approval?
    end
    measure_with_downloads('Chat.find + ask, 10 images of 1 MB', teardown: RailsApp.forget_new_rows) do
      Chat.find(chat.id).ask('Which picture is the brightest?')
    end
  end
end
