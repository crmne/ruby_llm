# frozen_string_literal: true

module MutationTesting
  # Runs every shard whose report is missing or out of date, one at a time,
  # and rewrites the combined report after each. Stopping loses only the shard
  # in progress. Mutineer times each mutant by the wall clock, so a pause can
  # turn the mutants in flight into timeouts, or fail a coverage capture; a
  # shard that was paused and came back incomplete runs again.
  class FullRun
    FREEZE_GAP = 20
    ATTEMPTS = 3

    attr_reader :root

    def initialize(root, out: $stdout)
      @root = root
      @out = out
    end

    def shards = @shards ||= MutationTesting.shards(root)

    def state(shard)
      meta = read_json(path(shard, 'meta.json'))
      current = meta && meta['digest'] == fingerprint.shard(shard)
      return :failed if current && meta['failed']
      return :done if current && File.exist?(path(shard, 'json'))

      File.exist?(path(shard, 'json')) ? :stale : :pending
    end

    def call
      lock = CassetteLock.new(root).acquire('full')
      watch_for_freezes
      results = shards.map { |shard| state(shard) == :done || run_shard(shard) }
      log "Finished: #{results.count(true)}/#{shards.size} shards done"
      results.all?
    ensure
      lock&.release
      FileUtils.rm_f(current_path)
    end

    def documents
      shards.filter_map { |shard| read_json(path(shard, 'json')) }
    end

    def write_report
      document = Report.combine(documents)
      File.write(File.join(state_dir, 'report.json'), "#{JSON.generate(document)}\n")
      File.write(File.join(state_dir, 'report.html'), Report.html(document))
      document
    end

    def current = read_json(current_path)

    def path(shard, extension) = File.join(state_dir, 'shards', "#{shard.name}.#{extension}")

    private

    def run_shard(shard)
      digest = fingerprint.shard(shard)
      ATTEMPTS.times do
        @frozen = false
        started_at = Time.now.utc.iso8601
        document = execute(shard, started_at)
        if @frozen && !complete?(document)
          log "#{shard.name}: paused while running, running it again"
          next
        end

        return record(shard, document, digest:, started_at:)
      end
      record(shard, nil, digest:, started_at: nil)
    end

    def execute(shard, started_at)
      FileUtils.mkdir_p(File.dirname(path(shard, 'json')))
      partial = path(shard, 'partial.json')
      FileUtils.rm_f(partial)
      write_json(current_path, shard: shard.name, pass: shard.pass.name, started_at:, pid: Process.pid)
      log "#{shard.name}: #{shard.sources.size} sources, #{shard.pass.name} specs"
      run_mutineer(shard, partial)
      document = read_json(partial)
      FileUtils.mv(partial, path(shard, 'json')) if document
      document
    end

    def run_mutineer(shard, output)
      command = MutationTesting.command(
        shard.pass, shard.sources, shard.pass.specs(root),
        cache_dir: File.join(state_dir, 'cache', shard.name), extra: ['--format', 'json', '--output', output]
      )
      pid = Process.spawn(MutationTesting.environment(shard.pass, 'full'), *command,
                          chdir: root, in: File::NULL, %i[out err] => [path(shard, 'log'), 'w'])
      Process.wait(pid)
      pid = nil
    ensure
      stop_child(pid) if pid
    end

    def stop_child(pid)
      Process.kill('TERM', pid)
      Process.wait(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end

    def record(shard, document, digest:, started_at:)
      write_json(path(shard, 'meta.json'), digest:, started_at:, finished_at: Time.now.utc.iso8601,
                                           failed: document.nil?)
      if document
        summary = document['summary']
        log "#{shard.name}: score #{summary['score'].inspect}, #{summary['survived']} survived of #{summary['total']}"
        write_report
      else
        log "#{shard.name}: no report; see #{path(shard, 'log')}"
      end
      document
    end

    def complete?(document)
      return false unless document

      document.dig('summary', 'timeout').zero? && document.dig('summary', 'errored').zero?
    end

    def watch_for_freezes
      Thread.new do
        last = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        loop do
          sleep 2
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @frozen = true if now - last > FREEZE_GAP
          last = now
        end
      end
    end

    def log(message)
      line = "[#{Time.now.strftime('%F %T')}] #{message}"
      @out.puts line
      @out.flush
      FileUtils.mkdir_p(state_dir)
      File.open(File.join(state_dir, 'runner.log'), 'a') { |file| file.puts line }
    end

    def fingerprint = @fingerprint ||= Fingerprint.new(root)

    def state_dir = MutationTesting.state_dir(root)

    def current_path = File.join(state_dir, 'current.json')

    def read_json(file)
      JSON.parse(File.read(file)) if File.file?(file)
    rescue JSON::ParserError
      nil
    end

    def write_json(file, data)
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, "#{JSON.generate(data)}\n")
    end
  end
end
