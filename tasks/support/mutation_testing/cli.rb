# frozen_string_literal: true

module MutationTesting
  # The bin/mutineer commands. A command fails by returning false.
  class CLI
    USAGE = <<~TEXT
      Usage: bin/mutineer COMMAND

        run [SOURCE...] [--spec SPEC]... [--all-specs] [-- MUTINEER_OPTIONS]
                  Mutate the given files or directories (default: the whole
                  library) in the foreground and print mutineer's report.
        check     Mutate the lines changed since the upstream branch (or
                  origin/main) and fail on survivors the full-run report does
                  not already list. The overcommit pre-push hook runs this.
        full      Run every out-of-date shard in the foreground.
        start     Run every out-of-date shard in the background (Linux).
        pause     Freeze the background run.
        resume    Thaw the background run.
        stop      Stop the background run; the next start resumes it.
        status    Show the run state, shards done, and the score so far.
        report    Write tmp/mutineer/report.json and report.html and list
                  survivors by file.
        unlock    Restore the cassette directories' permissions left by a
                  run that died (--force: even if a run still holds them).
    TEXT

    def initialize(root, out: $stdout)
      @root = root
      @out = out
    end

    def call(argv)
      command, *arguments = argv
      case command
      when 'run' then run(arguments)
      when 'check' then check
      when 'full' then full_run.call
      when 'start', 'pause', 'resume', 'stop' then background.public_send(command)
      when 'status' then status
      when 'report' then report
      when 'unlock' then unlock(arguments.include?('--force'))
      else
        @out.puts USAGE
        %w[help --help -h].include?(command)
      end
    end

    private

    def run(arguments)
      extra = arguments.index('--') ? arguments.slice!(arguments.index('--')..).drop(1) : []
      specs = []
      all_specs = !arguments.delete('--all-specs').nil?
      while (index = arguments.index('--spec'))
        specs << arguments.slice!(index, 2).last
      end
      sources = expand(arguments.empty? ? %w[lib/ruby_llm.rb lib/ruby_llm] : arguments)
      selection = all_specs ? nil : SpecSelection.new(@root)
      run_passes(sources, label: 'run', extra:) do |pass, pass_sources|
        chosen = specs.select { |spec| pass.specs(@root).include?(spec) }
        next chosen if chosen.any?

        selection ? selection.for(pass, pass_sources) : pass.specs(@root)
      end
    end

    def check
      return say('Mutineer needs MRI 3.4 or later; skipping the mutation check') unless MutationTesting.mutineer_version

      base = MutationTesting.git(@root, 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}') ||
             %w[origin/main main].find { |ref| MutationTesting.git(@root, 'rev-parse', '--verify', '--quiet', ref) }
      return say('No upstream branch or main to compare with; nothing to check') unless base

      merge_base = MutationTesting.git(@root, 'merge-base', base, 'HEAD')
      changed = MutationTesting.git(@root, 'diff', '--name-only', '--diff-filter=d', merge_base, '--', 'lib').to_s
      sources = changed.lines(chomp: true) & MutationTesting.sources(@root)
      return say("No library changes since #{base}") if sources.empty?

      say "Mutating lines changed since #{base} in #{sources.size} file(s)"
      selection = SpecSelection.new(@root, base: merge_base)
      run_passes(sources, label: 'check', extra: ['--since', merge_base, *gate]) do |pass, pass_sources|
        selection.for(pass, pass_sources)
      end
    end

    def gate
      baseline = File.join(MutationTesting.state_dir(@root), 'report.json')
      return ['--threshold', '100'] unless File.file?(baseline)

      say 'Comparing with tmp/mutineer/report.json: only new survivors fail'
      ['--baseline', baseline]
    end

    def run_passes(sources, label:, extra:)
      lock = CassetteLock.new(@root).acquire(label)
      by_pass = sources.group_by { |source| MutationTesting.pass_for(source) }.sort_by { |pass, _| pass.name }
      results = by_pass.map do |pass, files|
        say "#{pass.name} pass: #{files.size} source(s)"
        cache_dir = File.join(MutationTesting.state_dir(@root), 'cache', "#{label}-#{pass.name}")
        command = MutationTesting.command(pass, files, yield(pass, files), cache_dir:, extra:)
        system(MutationTesting.environment(pass, label), *command, chdir: @root)
      end
      results.all?
    ensure
      lock&.release
    end

    def expand(paths)
      library = MutationTesting.sources(@root)
      paths.flat_map do |path|
        relative = path.delete_prefix("#{@root}/").chomp('/')
        matches = library.select { |source| source == relative || source.start_with?("#{relative}/") }
        abort "#{path} is not a library source under lib/" if matches.empty?
        matches
      end.uniq
    end

    def status
      run = full_run
      states = run.shards.to_h { |shard| [shard, run.state(shard)] }
      done = states.select { |_, state| state == :done }.keys
      say "State: #{background.state}"
      say "Shards: #{done.size}/#{states.size} done#{counts(states)}"
      say current_line(run) if run.current
      totals = Report.combine(done.filter_map { |shard| JSON.parse(File.read(run.path(shard, 'json'))) })['summary']
      score = totals['score'] ? "#{totals['score']}%" : 'none yet'
      say "Score so far: #{score} (#{totals['killed']} killed, #{totals['survived']} survived in done shards)"
      say "Report: #{STATE_DIR}/report.html" if File.exist?(File.join(MutationTesting.state_dir(@root), 'report.html'))
    end

    def counts(states)
      tally = states.values.tally.except(:done)
      tally.empty? ? '' : ", #{tally.map { |state, count| "#{count} #{state}" }.join(', ')}"
    end

    def current_line(run)
      shard = run.shards.find { |candidate| candidate.name == run.current['shard'] }
      log = shard && run.path(shard, 'log')
      progress = File.file?(log.to_s) ? File.foreach(log).grep(/\A\[mutineer\] \d+/).last&.strip : nil
      "Now: #{run.current['shard']} since #{run.current['started_at']}#{" (#{progress})" if progress}"
    end

    def report
      document = full_run.write_report
      say "Score: #{document.dig('summary', 'score').inspect} " \
          "(#{document.dig('summary', 'killed')} killed, #{document.dig('summary', 'survived')} survived)"
      Report.survivors_by_file(document).each { |file, survivors| say "#{survivors.size.to_s.rjust(5)}  #{file}" }
      say "Wrote #{STATE_DIR}/report.json and #{STATE_DIR}/report.html"
    end

    def unlock(force)
      lock = CassetteLock.new(@root)
      force ? lock.release_all : lock.prune
      return say('Cassettes are writable') unless lock.locked?

      say "Cassettes stay read-only for: #{lock.holders.map { |holder| holder['label'] }.join(', ')}"
    end

    def full_run = FullRun.new(@root, out: @out)

    def background = Background.new(@root, out: @out)

    def say(message)
      @out.puts message
    end
  end
end
