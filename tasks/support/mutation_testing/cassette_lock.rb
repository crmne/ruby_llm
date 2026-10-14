# frozen_string_literal: true

require 'find'

module MutationTesting
  # Makes the cassette directories read-only while mutants run. A failing
  # example deletes its cassette so the next ordinary run records it again,
  # but a mutant's failure says nothing about the cassette, and once one is
  # gone later mutants would reach the real API. Several runs can hold the
  # lock at once; the directories get their modes back when the last holder
  # releases it, or on the next acquire or prune after a holder died.
  class CassetteLock
    def initialize(root)
      @root = root
      @dir = File.join(MutationTesting.state_dir(root), 'cassette-lock')
    end

    def acquire(label)
      synchronize do
        prune_holders
        protect unless File.exist?(modes_path)
        File.write(holder_path(Process.pid), JSON.generate(pid: Process.pid, boot: boot_id, label: label))
      end
      self
    end

    def release
      synchronize do
        FileUtils.rm_f(holder_path(Process.pid))
        prune_holders
      end
    end

    def prune
      synchronize { prune_holders }
    end

    def release_all
      synchronize do
        Dir.glob(File.join(@dir, 'holder-*.json')).each { |path| FileUtils.rm_f(path) }
        prune_holders
      end
    end

    def holders
      Dir.glob(File.join(@dir, 'holder-*.json')).filter_map do |path|
        JSON.parse(File.read(path))
      rescue JSON::ParserError
        nil
      end
    end

    def locked? = File.exist?(modes_path)

    private

    def synchronize(&)
      FileUtils.mkdir_p(@dir)
      File.open(File.join(@dir, 'lock'), File::RDWR | File::CREAT) do |file|
        file.flock(File::LOCK_EX)
        yield
      end
    end

    def prune_holders
      Dir.glob(File.join(@dir, 'holder-*.json')).each do |path|
        holder = JSON.parse(File.read(path))
        FileUtils.rm_f(path) unless alive?(holder)
      rescue JSON::ParserError
        FileUtils.rm_f(path)
      end
      restore if holders.empty? && File.exist?(modes_path)
    end

    def protect
      modes = directories.to_h { |dir| [dir, File.stat(dir).mode & 0o7777] }
      File.write(modes_path, JSON.generate(modes))
      modes.each { |dir, mode| File.chmod(mode & ~0o222, dir) }
    end

    def restore
      JSON.parse(File.read(modes_path)).each do |dir, mode|
        File.chmod(mode, dir) if File.directory?(dir)
      end
      FileUtils.rm_f(modes_path)
    end

    def directories
      CASSETTE_DIRS.map { |dir| File.join(@root, dir) }.select { |dir| File.directory?(dir) }.flat_map do |top|
        Find.find(top).select { |path| File.directory?(path) }
      end
    end

    def alive?(holder)
      return false unless holder['boot'] == boot_id

      Process.kill(0, holder['pid'])
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    def boot_id
      path = '/proc/sys/kernel/random/boot_id'
      File.read(path).strip if File.exist?(path)
    end

    def modes_path = File.join(@dir, 'modes.json')

    def holder_path(pid) = File.join(@dir, "holder-#{pid}.json")
  end
end
