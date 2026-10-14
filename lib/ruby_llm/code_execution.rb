# frozen_string_literal: true

require 'json'
require 'stringio'

module RubyLLM
  # CodeExecution is the +run_code+ tool Chat#with_code_execution gives the
  # model. Each call runs Ruby, Python, or a shell script in the configured
  # Sandbox, in a fresh working directory with read-only copies of the
  # conversation's files, and returns the exit code, the output, and every
  # file the code wrote as an attachment on the tool result.
  #
  #   chat = RubyLLM.chat.with_code_execution
  #   chat.tools[:run_code] # => #<RubyLLM::CodeExecution ...>
  class CodeExecution < Tool
    # The languages code execution can run.
    LANGUAGES = %i[ruby python shell].freeze

    # The options Chat#with_code_execution accepts.
    OPTIONS = %i[languages timeout network gems python gem_home virtualenv readable mounts].freeze

    # Seconds a run may take unless +timeout:+ says otherwise.
    DEFAULT_TIMEOUT = 120

    # Characters of standard output and of standard error kept per run.
    MAX_OUTPUT = 20_000

    # Files a run returns at most.
    MAX_FILES = 10

    # Bytes a returned file may have at most.
    MAX_FILE_SIZE = 10 * 1024 * 1024

    # Bytes of a text file the model reads back. Larger files, and files
    # that are not images, PDFs, or text, reach the model as a description.
    MAX_MODEL_TEXT = 64 * 1024

    CHECKS = {}.compare_by_identity
    CHECKS_LOCK = Mutex.new
    private_constant :CHECKS, :CHECKS_LOCK

    class << self
      def tool_name # :nodoc:
        'run_code'
      end

      # Returns the options +enabled+ and +options+ describe, +false+ when
      # disabled. Raises ArgumentError for anything else.
      def options(enabled, options) # :nodoc:
        return options(true, enabled.transform_keys(&:to_sym).merge(options)) if enabled.is_a?(Hash)
        unless [true, false].include?(enabled)
          raise ArgumentError, 'code execution accepts false or code execution options'
        end
        raise ArgumentError, 'disabled code execution does not accept options' if !enabled && options.any?
        return false unless enabled

        validate_options(options)
        options.merge(languages: languages_for(options)).freeze
      end

      # Returns +messages+ as the model reads them: files a run returned
      # stay attached when they are images, PDFs, or short text, and
      # become a description otherwise.
      def for_model(messages) # :nodoc:
        ids = messages.flat_map { |message| run_code_call_ids(message) }
        return messages if ids.empty?

        messages.map do |message|
          returned_files?(message, ids) ? message.with_attachments(model_view(message.attachments)) : message
        end
      end

      # Returns a text Attachment telling the model where its code finds
      # +attachment+.
      def describe(attachment) # :nodoc:
        name = Workspace.filename(attachment.filename)
        text = "#{name} (#{attachment.mime_type}, #{attachment.byte_size} bytes) is not shown here. " \
               "Code you run with #{tool_name} can read it at #{Workspace::ATTACHMENTS}/#{name}."
        Attachment.new(StringIO.new(text), filename: "#{name}.txt")
      end

      def available?(sandbox, language, **) # :nodoc:
        CHECKS_LOCK.synchronize do
          checks = CHECKS[sandbox] ||= {}
          return checks[language.name] if checks.key?(language.name)

          checks[language.name] = runs?(sandbox, language, **)
        end
      end

      # Returns +name+ as a path inside the working directory. Raises
      # ArgumentError for a path outside it, or inside a folder code
      # execution fills itself.
      def mount_name(name) # :nodoc:
        path = Workspace.mount_path(name)
        raise ArgumentError, "#{name.inspect} is reserved for skills" if path.split('/').first == Skill::Loader::MOUNT

        path
      end

      private

      def runs?(sandbox, language, **)
        result = sandbox.run(*language.check_command, timeout: 30, **)
        result.exit_code&.zero? && !result.timed_out? ? true : false
      rescue StandardError => e
        RubyLLM.logger.debug { "Code execution cannot run #{language.label}: #{e.class}: #{e.message}" }
        false
      end

      def validate_options(options)
        unknown = options.keys - OPTIONS
        raise ArgumentError, "code execution accepts #{OPTIONS.join(', ')}, got #{unknown.join(', ')}" if unknown.any?
        raise ArgumentError, 'code execution options cannot be nil' if options.value?(nil)
        raise ArgumentError, 'pass gems: or gem_home:, not both' if options.key?(:gems) && options.key?(:gem_home)
        if options.key?(:python) && options.key?(:virtualenv)
          raise ArgumentError, 'pass python: or virtualenv:, not both'
        end

        validate_mounts(options[:mounts]) if options.key?(:mounts)
      end

      def validate_mounts(mounts)
        return if mounts.is_a?(Proc)
        raise ArgumentError, 'mounts: takes a Hash or a Proc that returns one' unless mounts.is_a?(Hash)

        mounts.each_key { |name| mount_name(name) }
      end

      def languages_for(options)
        default = options[:python] || options[:virtualenv] ? %i[ruby python shell] : %i[ruby shell]
        languages = Array(options.fetch(:languages, default)).map { |language| language.to_s.to_sym }.uniq
        unsupported = languages - LANGUAGES
        if unsupported.any?
          raise ArgumentError, "code execution runs #{LANGUAGES.join(', ')}, got #{unsupported.join(', ')}"
        end
        raise ArgumentError, 'code execution needs at least one language' if languages.empty?

        languages.freeze
      end

      def returned_files?(message, ids)
        message.tool_result? && ids.include?(message.tool_call_id) && message.attachments.any?
      end

      def model_view(files)
        files.map { |file| readable_by_model?(file) ? file : describe(file) }
      end

      def run_code_call_ids(message)
        (message.tool_calls || {}).values.select { |call| call.name == tool_name }.map(&:id)
      end

      def readable_by_model?(attachment)
        attachment.image? || attachment.pdf? || (attachment.text? && attachment.byte_size <= MAX_MODEL_TEXT)
      end
    end

    # The seconds a run may take.
    attr_reader :timeout

    # The network access runs get: +false+, +true+, or
    # <tt>{ allow: [...] }</tt>, with the hosts the chat's permissions
    # granted added to the list.
    def network
      granted = grants[:network]
      return @network if @network == true || granted.empty?

      configured = @network.is_a?(Hash) ? Array(@network[:allow]) : []
      { allow: (configured + granted).uniq }
    end

    # The extra paths runs may read.
    attr_reader :readable

    # Returns the directories mounted read-only in each run's working
    # directory, keyed by their path there. Raises ArgumentError for a
    # path outside the working directory or a directory that does not
    # exist.
    def mounts
      mounts = @mounts.is_a?(Proc) ? @mounts.call : @mounts
      raise ArgumentError, 'mounts: takes a Hash or a Proc that returns one' unless mounts.is_a?(Hash)

      mounts.to_h do |name, directory|
        directory = File.expand_path(directory)
        raise ArgumentError, "#{directory} is not a directory" unless File.directory?(directory)

        [self.class.mount_name(name), File.realpath(directory)]
      end
    end

    # Creates the tool for +sandbox+ with the options Chat#with_code_execution
    # takes. +sandbox+ and +config+ may be Procs, called whenever the tool
    # needs them. +attachments+ returns the conversation's files when called,
    # and +skills+ a Hash of paths under +skills/+ to the skill folders
    # mounted there. +mounts+ is a Hash of paths inside the working
    # directory to directories mounted there read-only, or a Proc called
    # before each run that returns one. +chat+ and +config+ describe
    # where the instrumentation events go. +grants+ returns the hosts and
    # paths the chat's permissions granted, and +requests+ whether the model
    # can ask for more with +request_permission+.
    # Raises ConfigurationError without a sandbox.
    def initialize(sandbox:, attachments: -> { [] }, skills: -> { {} }, mounts: {}, chat: nil, config: nil,
                   package_cache_dir: nil, languages: %i[ruby shell], timeout: DEFAULT_TIMEOUT, network: false,
                   readable: [], grants: -> { {} }, requests: -> { false }, **packages)
      super()
      @sandbox = sandbox
      self.sandbox
      @attachments = attachments
      @skills = skills
      @mounts = mounts
      @chat = chat
      @config = config
      @requested_languages = languages
      @timeout = timeout
      @network = network
      @readable = Array(readable).map { |path| File.expand_path(path) }
      @grants = grants
      @requests = requests
      @packages = Packages.new(sandbox: -> { self.sandbox }, cache_dir: package_cache_dir, **packages)
    end

    # Returns whether runs change nothing outside the sandbox: +true+ until
    # the chat's permissions grant a writable path.
    def read_only?
      grants[:writable].empty?
    end

    # Returns the Sandbox the code runs in. Raises ConfigurationError when
    # there is none.
    def sandbox
      current = @sandbox.is_a?(Proc) ? @sandbox.call : @sandbox
      current || raise(ConfigurationError, 'Code execution needs a sandbox. Set config.sandbox = :mxc.')
    end

    # Returns the languages the model may use: those requested that the
    # sandbox can run. Raises ConfigurationError when it can run none.
    def languages
      (@languages ||= {}.compare_by_identity)[sandbox] ||= begin
        options = { env: @packages.base_env(Dir.tmpdir), readable: RubyInstallation.current.readable,
                    denied: @packages.denied }
        available = @requested_languages.select { |name| self.class.available?(sandbox, Language[name], **options) }
        raise ConfigurationError, "The sandbox cannot run #{@requested_languages.join(', ')}" if available.empty?

        available
      end
    end

    # Returns the description the model sees, naming only the languages
    # the sandbox can run.
    def description
      [
        "Runs #{language_list} code in a sandbox and returns its exit code, output, and the files it writes.",
        'Each call starts in a new empty working directory, and nothing carries over between calls.',
        "Files attached to the conversation, and files earlier calls returned, are in ./#{Workspace::ATTACHMENTS} " \
        '(read-only). Write files to the working directory to return them to the user.',
        mounts_note,
        packages_note,
        network_note,
        requests_note,
        "A call stops after #{timeout} seconds."
      ].compact.join(' ')
    end

    # Returns the JSON Schema of the +language+ and +code+ arguments.
    def parameters_schema
      {
        'type' => 'object',
        'properties' => {
          'language' => { 'type' => 'string', 'enum' => languages.map(&:to_s),
                          'description' => 'The language the code is written in' },
          'code' => { 'type' => 'string', 'description' => 'The complete program to run' }
        },
        'required' => %w[language code],
        'additionalProperties' => false,
        'strict' => true
      }
    end

    # Runs +code+ written in +language+ and returns its report, followed by
    # the files it wrote as Attachments.
    def execute(language:, code:, tool_call: nil)
      language = language.to_s.downcase.to_sym
      unless languages.include?(language)
        return { error: "Unsupported language #{language}. Use one of: #{languages.join(', ')}" }
      end

      Workspace.open { |workspace| run(Language[language], code, workspace, tool_call) }
    end

    private

    def run(language, code, workspace, tool_call)
      workspace.copy_in(@attachments.call)
      mounted = workspace.mount(mounts.merge(@skills.call))
      script = workspace.write_source(language, code)
      instrument(language, tool_call) do |event|
        result = run_in_sandbox(language.command(script), workspace, readable: mounted)
        files, skipped = workspace.outputs(max_files: MAX_FILES, max_size: MAX_FILE_SIZE)
        record(event, result, files)
        files.empty? ? report(result, files, skipped) : [report(result, files, skipped), *files]
      end
    end

    def run_in_sandbox(command, workspace, readable:)
      granted = grants
      network = self.network
      environment = environment_for(granted)
      sandbox.run(*command,
                  readable: [*@packages.readable, *@packages.resolver_config(network), *self.readable,
                             *granted[:readable], *environment&.readable, *readable, workspace.source,
                             workspace.inputs],
                  denied: @packages.denied,
                  writable: [workspace.directory, workspace.home, workspace.tmp, *granted[:writable],
                             *environment&.writable],
                  network:, timeout:, directory: workspace.directory,
                  env: run_env(workspace, environment))
    end

    def run_env(workspace, environment)
      env = @packages.env(workspace.home, workspace.tmp)
      environment ? environment.env(env) : env
    end

    def environment_for(granted)
      return unless granted[:environment]

      Environment.new(@packages, granted[:environment]).tap do |environment|
        environment.prepare(python: languages.include?(:python))
      end
    end

    def grants
      granted = @grants.call
      writable = Array(granted[:writable])
      readable = Array(granted[:readable]).reject do |path|
        writable.any? { |parent| Chat::Permissions.covers_path?(parent, path) }
      end
      { network: Array(granted[:network]), readable:, writable:, environment: granted[:environment] }
    end

    def instrument(language, tool_call)
      payload = { chat: @chat, tool_call_id: tool_call&.id, tool_name: name, language: language.name, timeout:,
                  network: }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      config = @config.is_a?(Proc) ? @config.call : @config
      RubyLLM.instrument('code_execution.ruby_llm', payload, config:) do |event|
        yield event
      ensure
        event[:duration] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end
    end

    def record(event, result, files)
      event[:exit_code] = result.exit_code
      event[:timed_out] = result.timed_out?
      event[:blocked_hosts] = Array(result.blocked) if result.respond_to?(:blocked)
      event[:files] = files.map(&:filename)
    end

    def report(result, files, skipped)
      blocked = Array(result.blocked) if result.respond_to?(:blocked)
      {
        exit_code: result.exit_code,
        stdout: truncate(result.stdout),
        stderr: truncate(result.stderr),
        error: ("The code ran past the #{timeout}-second limit and was stopped" if result.timed_out?),
        blocked_hosts: (blocked if blocked&.any?),
        hint: blocked_hint(blocked),
        files: (files.map(&:filename) if files.any?),
        skipped_files: (skipped if skipped.any?)
      }.compact.to_json
    end

    def blocked_hint(blocked)
      'Ask for access to the blocked hosts with request_permission.' if blocked&.any? && @requests.call
    end

    def truncate(text)
      text = text.to_s.dup.force_encoding(Encoding::UTF_8).scrub
      return text if text.length <= MAX_OUTPUT

      half = MAX_OUTPUT / 2
      "#{text[0, half]}\n[#{text.length - MAX_OUTPUT} characters omitted]\n#{text[-half..]}"
    end

    def language_list
      labels = languages.map { |name| Language[name].label }
      labels.size > 1 ? "#{labels[0..-2].join(', ')} or #{labels.last}" : labels.first
    end

    def mounts_note
      names = mounts.keys
      "These folders are available read-only: #{names.map { |name| "./#{name}" }.join(', ')}." if names.any?
    end

    def packages_note
      notes = []
      gems = @packages.gem_names
      python = @packages.python_names
      notes << "Ruby #{RUBY_VERSION} has these gems: #{gems.join(', ')}." if gems.any?
      notes << "Python has these packages: #{python.join(', ')}." if python.any?
      notes.join(' ') unless notes.empty?
    end

    def network_note
      case @network
      when true then 'The code can reach the network.'
      when Hash then "The code can only reach these hosts: #{Array(@network[:allow]).join(', ')}."
      else 'The code has no network access.'
      end
    end

    def requests_note
      return unless @requests.call

      'To reach a host or a path the code cannot reach, ask for it with request_permission first.'
    end
  end
end
