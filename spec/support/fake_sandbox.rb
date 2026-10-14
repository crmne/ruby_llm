# frozen_string_literal: true

# A sandbox that records each run and answers with a block, so specs can
# check what code execution asks a sandbox to do without starting one.
class FakeSandbox
  Result = Struct.new(:stdout, :stderr, :exit_code, :timed_out, :blocked, keyword_init: true) do
    def timed_out?
      timed_out
    end
  end

  attr_reader :runs

  def self.result(stdout: '', stderr: '', exit_code: 0, timed_out: false, blocked: [])
    Result.new(stdout:, stderr:, exit_code:, timed_out:, blocked:)
  end

  def initialize(supported: true, missing: [], &handler)
    @supported = supported
    @missing = missing
    @handler = handler
    @runs = []
    @lock = Mutex.new
  end

  def supported?
    @supported
  end

  def run(*command, timeout:, readable: [], writable: [], denied: [], network: false, directory: nil, env: {})
    run = { command:, readable:, writable:, denied:, network:, timeout:, directory:, env: }
    @lock.synchronize { @runs << run }
    return self.class.result(stderr: "#{command.first}: not found", exit_code: 127) if @missing.include?(command.first)

    @handler && !check?(command) ? @handler.call(run) : self.class.result
  end

  def check?(command)
    command.size == 3 && ['exit', 'pass', 'exit 0'].include?(command.last)
  end

  def code_runs
    runs.select { |run| run[:command].last.to_s.match?(/main\.(rb|py|sh)\z/) }
  end
end
