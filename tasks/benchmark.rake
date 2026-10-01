# frozen_string_literal: true

require 'English'
require 'fileutils'
require 'tmpdir'
require_relative '../benchmarks/support/report'

# Runs the scripts in benchmarks/ in their own bundle, against this checkout
# or against lib/ and spec/dummy/ exported from a git ref.
module BenchmarkRunner
  ROOT = File.expand_path('..', __dir__)
  DIRECTORY = File.join(ROOT, 'benchmarks')
  GEMFILE = File.join(DIRECTORY, 'Gemfile')
  RESULTS = File.join(ROOT, 'tmp/benchmark/results')
  ORDER = %w[connections vertex_ai streaming requests memory registry transcript attachments
             provider_files].freeze

  module_function

  def areas(name)
    available = Dir[File.join(DIRECTORY, '*.rb')].map { |path| File.basename(path, '.rb') }
    return (ORDER & available) | available.sort if name.nil?
    return [name] if available.include?(name)

    abort "Unknown benchmark #{name}. Choose one of: #{available.sort.join(', ')}"
  end

  # The benchmark bundle adds a few gems to the development bundle, starting
  # from its lockfile so both resolve the same versions.
  def install
    lockfile = "#{GEMFILE}.lock"
    development_lockfile = File.join(ROOT, 'Gemfile.lock')
    FileUtils.cp(development_lockfile, lockfile) if !File.exist?(lockfile) && File.exist?(development_lockfile)
    Bundler.with_unbundled_env do
      env = { 'BUNDLE_GEMFILE' => GEMFILE }
      next if system(env, 'bundle', 'check', out: File::NULL)

      system(env, 'bundle', 'install') || abort('Could not install the benchmark bundle')
    end
  end

  # Another version lives outside the checkout, where RuboCop and the specs
  # never find its files.
  def target(ref)
    return [ROOT, working_tree_label] unless ref

    sha = git('rev-parse', '--verify', "#{ref}^{commit}")
    root = File.join(Dir.tmpdir, "ruby_llm-benchmark-#{sha}")
    export(sha, root) unless File.exist?(File.join(root, 'lib/ruby_llm.rb'))
    [root, "#{ref} (#{sha[0, 8]})"]
  end

  def working_tree_label
    changed = !git('status', '--porcelain', '--', 'lib', 'spec/dummy').empty?
    "#{git('rev-parse', '--short=8', 'HEAD')}#{' with changes' if changed}"
  end

  def export(sha, root)
    archive = IO.popen(['git', '-C', ROOT, 'archive', '--format=tar', sha, 'lib', 'spec/dummy'], 'rb', &:read)
    abort "Could not export #{sha}" unless $CHILD_STATUS.success?

    FileUtils.mkdir_p(root)
    IO.popen(['tar', '-x', '-C', root], 'wb') { |tar| tar.write(archive) }
    abort "Could not unpack #{sha}" unless $CHILD_STATUS.success?
  end

  def git(*arguments)
    output = IO.popen(['git', '-C', ROOT, *arguments], &:read).strip
    abort "git #{arguments.join(' ')} failed" unless $CHILD_STATUS.success?
    output
  end

  def run(area, root:, label:, output: nil)
    env = { 'BUNDLE_GEMFILE' => GEMFILE, 'BENCH_ROOT' => root, 'BENCH_LABEL' => label, 'BENCH_OUTPUT' => output }
    Bundler.with_unbundled_env do
      system(env.compact, 'bundle', 'exec', 'ruby', File.join(DIRECTORY, "#{area}.rb")) ||
        abort("The #{area} benchmark failed against #{label}")
    end
  end

  # Alternates between the two versions for BENCH_ROUNDS rounds, so drift in
  # the machine's load reaches both, and prints the runs of all rounds.
  def compare(area, base, head)
    FileUtils.mkdir_p(RESULTS)
    reports = Integer(ENV.fetch('BENCH_ROUNDS', 1)).times.flat_map do |round|
      [base, head].map do |root, label|
        output = File.join(RESULTS, "#{area}-#{round}-#{label.gsub(/\W+/, '-')}.json")
        run(area, root:, label:, output:)
        Benchmarks::Report.load(output)
      end
    end
    before, after = reports.partition.with_index { |_report, index| index.even? }
    puts Benchmarks::Report.compare(Benchmarks::Report.merge(before), Benchmarks::Report.merge(after))
  end
end

desc 'Run the speed benchmarks in benchmarks/ (one area, or all) against this checkout, or BENCH_REF'
task :benchmark, [:area] do |_task, args|
  BenchmarkRunner.install
  root, label = BenchmarkRunner.target(ENV.fetch('BENCH_REF', nil))
  BenchmarkRunner.areas(args[:area]).each { |area| BenchmarkRunner.run(area, root:, label:) }
end

namespace :benchmark do
  desc 'Compare the speed benchmarks (one area, or all) of a git ref, such as v2.0.0, with this checkout'
  task :compare, %i[base area] do |_task, args|
    abort 'Name the version to compare with: rake "benchmark:compare[v2.0.0]"' unless args[:base]

    BenchmarkRunner.install
    base = BenchmarkRunner.target(args[:base])
    head = BenchmarkRunner.target(nil)
    BenchmarkRunner.areas(args[:area]).each { |area| BenchmarkRunner.compare(area, base, head) }
  end
end
