# frozen_string_literal: true

require 'English'
require 'fileutils'
require 'json'
require 'logger'
require_relative 'report'

# Loads the RubyLLM under test and measures it. BENCH_ROOT names a checkout
# (a directory with lib/ and spec/dummy/), so the same benchmark measures
# any version; it defaults to the checkout these benchmarks live in.
module Benchmarks
  ROOT = File.expand_path(ENV.fetch('BENCH_ROOT', File.expand_path('../..', __dir__)))
  SCRATCH = File.expand_path('../../tmp/benchmark', __dir__)

  $LOAD_PATH.unshift(File.join(ROOT, 'lib'))
  require 'ruby_llm'

  class << self
    attr_reader :report

    # Runs one area's cases and prints their results. BENCH_OUTPUT names a
    # JSON file to write them to, for comparisons.
    def area(name)
      $stdout.sync = true
      @report = Report.new(name, ENV.fetch('BENCH_LABEL', ROOT))
      puts "#{name}: RubyLLM from #{ROOT}, #{RUBY_DESCRIPTION}"
      yield
      puts report
      report.write(ENV['BENCH_OUTPUT']) if ENV['BENCH_OUTPUT']
    end

    # BENCH_RUNS overrides every case's number of runs.
    def runs(default)
      Integer(ENV.fetch('BENCH_RUNS', default))
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # Times +iterations+ calls of the block per run, after +warmup+ calls,
    # and records the time and the objects allocated per call. +counters+
    # names other readings to record as their change over each run, and
    # +teardown+ runs untimed after each run and each warmup call.
    def measure(name, runs: 10, warmup: 2, iterations: 1, counters: {}, teardown: nil, &block)
      warmup.times do
        block.call
        teardown&.call
      end
      times = []
      allocations = []
      counts = counters.transform_values { [] }
      runs(runs).times do
        GC.start
        before = counters.transform_values(&:call)
        allocated = GC.stat(:total_allocated_objects)
        started = now
        iterations.times { block.call }
        times << ((now - started) * 1000 / iterations)
        allocations << (GC.stat(:total_allocated_objects) - allocated).fdiv(iterations).round
        counters.each { |metric, counter| counts[metric] << (counter.call - before[metric]) }
        teardown&.call
      end
      record(name, :time, 'ms', times)
      record(name, :allocations, 'objects', allocations)
      counts.each { |metric, values| record(name, metric, '', values) }
    end

    def record(name, metric, unit, values)
      report.add(name, metric, unit, Array(values))
    end

    # Runs the block in a forked child, so each run starts from the state of
    # a new process, and returns what the block returned, through JSON.
    def forked
      reader, writer = IO.pipe
      pid = fork do
        reader.close
        writer.write(JSON.generate(result: yield))
        exit!(0)
      rescue StandardError, ScriptError => e
        writer.write(JSON.generate(error: e.full_message))
        exit!(1)
      end
      writer.close
      output = reader.read
      Process.wait(pid)
      output = output.empty? ? { 'error' => "it exited with #{$CHILD_STATUS}" } : JSON.parse(output)
      raise "Benchmark child failed:\n#{output['error']}" if output.key?('error')

      output['result']
    ensure
      reader&.close
    end

    # Runs the block in a forked child, and adds what it recorded to this
    # area's results.
    def isolated
      recorded = forked do
        @report = Report.new(report.area, report.target)
        yield
        report.series.map(&:to_h)
      end
      recorded.each { |series| report.series << Series.from_h(series) }
    end

    def scratch(*path)
      File.join(SCRATCH, *path).tap { |dir| FileUtils.mkdir_p(dir) }
    end

    # Configures RubyLLM the same way for every benchmark: the bundled model
    # registry, no retries, and no log output.
    def configure(**options)
      RubyLLM.configure do |config|
        config.model_registry_file = nil
        config.max_retries = 0
        config.logger = Logger.new(File::NULL)
        options.each { |option, value| config.public_send(:"#{option}=", value) }
      end
    end
  end
end
