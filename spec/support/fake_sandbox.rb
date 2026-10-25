# frozen_string_literal: true

# A sandbox that records each run and answers with a block, so specs can
# check what code execution asks a sandbox to do without starting one.
# Given +output+, it yields those pieces, one by one, to a run that asks
# for its output as it arrives: a String for standard output, or
# <tt>{ stderr: '...' }</tt> for standard error.
class FakeSandbox
  Chunk = Struct.new(:content, :stream)

  Result = Struct.new(:stdout, :stderr, :exit_code, :timed_out, :blocked, :cpu_time, :limit_exceeded,
                      keyword_init: true) do
    def timed_out?
      timed_out
    end
  end

  attr_reader :runs, :timeout, :network, :directory, :readable, :writable, :limits

  def self.result(stdout: '', stderr: '', exit_code: 0, timed_out: false, blocked: [], cpu_time: nil,
                  limit_exceeded: nil)
    Result.new(stdout:, stderr:, exit_code:, timed_out:, blocked:, cpu_time:, limit_exceeded:)
  end

  def initialize(supported: true, missing: [], timeout: nil, network: false, directory: nil, readable: [],
                 writable: [], limits: {}, output: [], &handler)
    @supported = supported
    @missing = missing
    @timeout = timeout
    @network = network
    @directory = directory
    @readable = readable
    @writable = writable
    @limits = limits
    @handler = handler
    @output = output
    @runs = []
    @lock = Mutex.new
  end

  def supported?
    @supported
  end

  def run(*command, timeout:, readable: [], writable: [], denied: [], directory: nil, env: {}, network: nil)
    run = { command:, readable:, writable:, denied:, network:, timeout:, directory:, env:, streamed: block_given? }
    @lock.synchronize { @runs << run }
    @output.each { |piece| yield chunk(piece) } if block_given? && !check?(command)
    return self.class.result(stderr: "#{command.first}: not found", exit_code: 127) if @missing.include?(command.first)

    @handler && !check?(command) ? @handler.call(run) : self.class.result
  end

  def chunk(piece)
    stream, content = piece.is_a?(Hash) ? piece.first : [:stdout, piece]
    Chunk.new(content, stream)
  end

  def check?(command)
    command.size == 3 && ['exit', 'pass', 'exit 0', '0'].include?(command.last)
  end

  def code_runs
    runs.select { |run| run[:command].last.to_s.match?(/main\.(rb|py|sh)\z/) }
  end
end
