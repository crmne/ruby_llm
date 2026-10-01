# frozen_string_literal: true

# A persisted chat that sent a 30 MB PDF to Anthropic, which takes a file that
# large only through its Files API, then five more turns, each asked from the
# chat loaded in a new process, as web requests and jobs do. Counts what each
# turn uploads to the provider and downloads from Active Storage.
require_relative 'support/rails_app'

RailsApp = Benchmarks::RailsApp
Payloads = Benchmarks::Payloads
Canned = Benchmarks::CannedAdapter

PDF_BYTES = 30 * 1024 * 1024
TURNS = 5
FILE = JSON.generate(id: 'file_benchmark', type: 'file', filename: 'report.pdf', mime_type: 'application/pdf',
                     size_bytes: PDF_BYTES, created_at: '2026-10-01T09:00:00Z', downloadable: false)

PDF = File.join(Benchmarks.scratch('files'), 'report-30mb.pdf')
File.binwrite(PDF, Payloads.pdf(PDF_BYTES)) unless File.exist?(PDF)
SMALL_PDF = File.join(Benchmarks.scratch('files'), 'memo-16kb.pdf')
File.binwrite(SMALL_PDF, Payloads.pdf(16 * 1024)) unless File.exist?(SMALL_PDF)

def route(stats)
  Canned.route(%r{/v1/messages\z}, json: Payloads.anthropic('Noted.'))
  Canned.route(%r{/v1/files\z}, verb: :post) do |request|
    stats['uploads'] += 1
    stats['uploaded_mb'] += request.bytes / (1024 * 1024)
    FILE
  end
  Canned.route(%r{/v1/files/file_benchmark\z}, verb: :get) do
    stats['lookups'] += 1
    FILE
  end
end

# Boots the app in a new process and asks another chat with a small PDF
# first, as a worker that has served other requests would have, so the
# measured ask pays only for its own chat. Returns what that ask took.
def turn(fresh:)
  Benchmarks.forked do
    RailsApp.boot(database: 'provider_files', fresh:)
    stats = Hash.new(0)
    route(stats)
    Chat.create!(model: 'claude-haiku-4-5').ask('Read this memo.', with: SMALL_PDF)
    stats['downloads'] = RailsApp.downloads do
      started = Benchmarks.now
      stats['result'] = yield
      stats['ms'] = (Benchmarks.now - started) * 1000
    end
    stats
  end
end

def conversation
  first = turn(fresh: true) do
    Chat.create!(model: 'claude-haiku-4-5').tap { |chat| chat.ask('Summarize the report.', with: PDF) }.id
  end
  turns = Array.new(TURNS) do |index|
    turn(fresh: false) { Chat.find(first['result']).ask("Follow-up question #{index + 1}?").content }
  end
  [first, turns]
end

Benchmarks.area('provider_files') do
  results = Array.new(Benchmarks.runs(3)) { conversation }
  firsts = results.map(&:first)
  turns = results.map(&:last)
  totals = ->(key) { turns.map { |run| run.sum { |stats| stats.fetch(key, 0) } } }

  Benchmarks.record('First ask with a 30 MB PDF', :time, 'ms', firsts.map { |stats| stats['ms'] })
  Benchmarks.record('First ask with a 30 MB PDF', :uploads, '', firsts.map { |stats| stats.fetch('uploads', 0) })
  name = "#{TURNS} later turns, each in a new process"
  Benchmarks.record(name, :time_per_turn, 'ms', turns.flatten.map { |stats| stats['ms'] })
  Benchmarks.record(name, :uploads, '', totals.call('uploads'))
  Benchmarks.record(name, :uploaded, 'MB', totals.call('uploaded_mb'))
  Benchmarks.record(name, :storage_downloads, '', totals.call('downloads'))
  Benchmarks.record(name, :file_lookups, '', totals.call('lookups'))
end
