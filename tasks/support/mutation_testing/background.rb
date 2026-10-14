# frozen_string_literal: true

module MutationTesting
  # Runs the full run as a transient systemd user unit at idle priority, so a
  # game or a build takes the CPU first. Freezing the unit pauses every
  # process in it; stopping it ends the shard in progress, and the next start
  # picks up from the first shard without a current report.
  class Background
    ENVIRONMENT = %w[PATH LANG LC_ALL GEM_HOME GEM_PATH RUBYLIB].freeze
    PROPERTIES = %w[Nice=19 CPUSchedulingPolicy=idle CPUWeight=idle IOSchedulingClass=idle].freeze

    def initialize(root, out: $stdout)
      @root = root
      @out = out
    end

    def available?
      RUBY_PLATFORM.include?('linux') && system('systemctl', '--user', '--version', out: File::NULL, err: File::NULL)
    end

    def start
      return say("#{UNIT} is already #{state}; see bin/mutineer status", result: false) if active?

      CassetteLock.new(@root).prune
      outcome(system('systemd-run', *start_arguments), "Started #{UNIT}", "Could not start #{UNIT}")
    end

    def pause = control('freeze', 'Paused')

    def resume = control('thaw', 'Resumed')

    def stop
      system('systemctl', '--user', 'thaw', UNIT, err: File::NULL) if state == 'paused'
      control('stop', 'Stopped')
    end

    def state
      return 'unavailable' unless available?

      properties = show('ActiveState', 'FreezerState')
      return 'not running' unless %w[active activating reloading deactivating].include?(properties['ActiveState'])

      properties['FreezerState'].to_s.start_with?('fr') ? 'paused' : 'running'
    end

    def active? = %w[running paused].include?(state)

    private

    def start_arguments
      executable = File.join(@root, 'bin/mutineer')
      [
        '--user', "--unit=#{UNIT}", '--collect', '--quiet', "--working-directory=#{@root}",
        *PROPERTIES.flat_map { |property| ['-p', property] },
        '-p', %(ExecStopPost="#{RbConfig.ruby}" "#{executable}" unlock),
        *environment.flat_map { |key, value| ["--setenv=#{key}=#{value}"] },
        RbConfig.ruby, executable, 'full'
      ]
    end

    def environment
      ENV.slice(*ENVIRONMENT).merge('BUNDLE_GEMFILE' => File.join(@root, 'Gemfile'))
    end

    def control(verb, done)
      return say("#{UNIT} is not running", result: false) unless active?

      outcome(system('systemctl', '--user', verb, UNIT), done, "systemctl #{verb} failed")
    end

    def outcome(succeeded, success, failure)
      say(succeeded ? success : failure, result: succeeded)
    end

    def show(*names)
      output, = Open3.capture2('systemctl', '--user', 'show', UNIT, *names.map { |name| "--property=#{name}" })
      output.lines(chomp: true).to_h { |line| line.split('=', 2) }
    end

    def say(message, result: true)
      @out.puts message
      result
    end
  end
end
