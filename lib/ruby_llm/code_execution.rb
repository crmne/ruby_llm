# frozen_string_literal: true

require 'json'
require 'stringio'

module RubyLLM
  # CodeExecution is the +run_code+ tool Chat#with_code_execution gives the
  # model. Each call runs Ruby, Python, JavaScript, or a shell script in a Sandbox, in a
  # fresh run directory with read-only copies of the conversation's files,
  # and returns the exit code, the output, and every file the code wrote
  # there as an attachment on the tool result. In a chat with a file store
  # (see Chat#with_file_store), runs work with the chat's files instead.
  # With a store that keeps its files in a folder (FileStore#local_root),
  # such as FileStore::Directory, code runs in that folder and changes the
  # files in place. With any other store, each run starts empty, copies in
  # the files the model names in +files+, and what the code writes is saved
  # back to the store.
  #
  # Calls run in the chat's default sandbox. With +escalate_to:+, the model
  # may name a wider sandbox for one call and say why; that call waits for
  # Chat#approve, and the next call is back in the default.
  #
  #   chat = RubyLLM.chat.with_code_execution(escalate_to: [WorkspaceSandbox])
  #   chat.tools[:run_code].escalations # => ["workspace"]
  class CodeExecution < Tool
    # The languages code execution can run.
    LANGUAGES = %i[ruby python javascript shell].freeze

    # The options Chat#with_code_execution accepts.
    OPTIONS = %i[sandbox escalate_to languages gems python npm gem_home virtualenv node_modules mounts].freeze

    # Characters of standard output and of standard error kept per run.
    MAX_OUTPUT = 20_000

    # Files a run returns at most.
    MAX_FILES = 10

    # Bytes a returned file may have at most.
    MAX_FILE_SIZE = 10 * 1024 * 1024

    # Bytes of a text file the model reads back. Larger files, and files
    # that are not images, PDFs, or text, reach the model as a description.
    MAX_MODEL_TEXT = 64 * 1024

    # The environment variable holding a run's directory, for code that
    # starts in a sandbox's own directory.
    RUN_DIR = 'RUN_DIR'

    ESCALATION_NAME = /\A[a-z][a-z0-9_]*\z/
    LIMIT_ERRORS = {
      cpu_time: 'The code used up its CPU time and was stopped',
      memory: 'The code used more memory than it may and was stopped',
      processes: 'The code started more processes than it may and was stopped'
    }.freeze

    # A WeakMap holds its values weakly too, so each check is kept as true
    # or false, which are never collected.
    CHECKS = Hash.new { |checks, language| checks[language] = ObjectSpace::WeakMap.new }
    CHECKS_LOCK = Mutex.new
    FILES_PROPERTY = {
      'type' => %w[array null], 'items' => { 'type' => 'string' },
      'description' => "Paths of this chat's files (see list_files) the code reads, copied into the run directory " \
                       'at the same paths; a folder copies everything in it. null copies nothing'
    }.freeze
    private_constant :CHECKS, :CHECKS_LOCK, :ESCALATION_NAME, :LIMIT_ERRORS, :FILES_PROPERTY

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

      # Returns the sandboxes +escalate_to+ names, as a Hash of names to
      # sandboxes. Raises ArgumentError for a name the model cannot use or
      # two sandboxes with the same name.
      def escalations(escalate_to) # :nodoc:
        named_sandboxes(escalate_to).each_with_object({}) do |(name, sandbox), escalations|
          raise ArgumentError, "#{name.inspect} is not a name like workspace" unless name.match?(ESCALATION_NAME)
          raise ArgumentError, "Two sandboxes are named #{name}" if escalations.key?(name)
          raise ArgumentError, "escalate_to: takes sandboxes, got nil for #{name}" if sandbox.nil?

          escalations[name] = sandbox
        end.freeze
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

      def available?(key, sandbox, language, **) # :nodoc:
        CHECKS_LOCK.synchronize do
          checks = CHECKS[[language.name, (sandbox.backend if sandbox.respond_to?(:backend))]]
          return checks[key] if checks.key?(key)

          checks[key] = runs?(sandbox, language, **)
        end
      end

      # Returns +name+ as a path inside the run directory. Raises
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

      def named_sandboxes(escalate_to)
        return escalate_to.map { |name, sandbox| [name.to_s, sandbox] } if escalate_to.is_a?(Hash)

        Array(escalate_to).map { |sandbox| [Sandbox.name_for(sandbox), sandbox] }
      end

      def validate_options(options)
        unknown = options.keys - OPTIONS
        raise ArgumentError, "code execution accepts #{OPTIONS.join(', ')}, got #{unknown.join(', ')}" if unknown.any?
        raise ArgumentError, 'code execution options cannot be nil' if options.value?(nil)

        validate_packages(options)
        escalations(options[:escalate_to]) if options.key?(:escalate_to)
        validate_mounts(options[:mounts]) if options.key?(:mounts)
      end

      def validate_packages(options)
        { gems: :gem_home, python: :virtualenv, npm: :node_modules }.each do |declared, prebuilt|
          next unless options.key?(declared) && options.key?(prebuilt)

          raise ArgumentError, "pass #{declared}: or #{prebuilt}:, not both"
        end
      end

      def validate_mounts(mounts)
        return if mounts.is_a?(Proc)
        raise ArgumentError, 'mounts: takes a Hash or a Proc that returns one' unless mounts.is_a?(Hash)

        mounts.each_key { |name| mount_name(name) }
      end

      def languages_for(options)
        default = [:ruby, (:python if options[:python] || options[:virtualenv]),
                   (:javascript if options[:npm] || options[:node_modules]), :shell].compact
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

    # Creates the tool with the options Chat#with_code_execution takes.
    # +sandbox+ is the default sandbox, or a Proc returning it, and
    # +escalate_to+ the sandboxes the model may ask for, an Array or a Hash
    # of names to sandboxes. +attachments+ returns the conversation's files
    # when called, and +skills+ a Hash of paths under +skills/+ to the
    # skill folders mounted there. +file_store+ returns the chat's
    # FileStore, or +nil+: with one, runs work with its files instead of
    # the attachments, in its folder when it has one, and each file a run
    # writes or changes is passed to +written+. +mounts+ is a Hash of paths inside the
    # run directory to directories mounted there read-only, or a Proc called
    # before each run that returns one. +approval+ is called with the
    # ToolCall of each escalated run right before it runs, and the run goes
    # ahead only when it returns +true+. +chat+ and +config+ describe where
    # the instrumentation events go.
    # Raises ConfigurationError without a sandbox.
    def initialize(sandbox:, escalate_to: [], attachments: -> { [] }, file_store: -> {}, written: ->(_file) {},
                   skills: -> { {} }, mounts: {}, approval: ->(_tool_call) { false }, chat: nil, config: nil,
                   package_cache_dir: nil, languages: %i[ruby shell], **packages)
      super()
      @sandbox = sandbox
      @config = config
      self.sandbox
      @escalate_to = self.class.escalations(escalate_to)
      @attachments = attachments
      @file_store = file_store
      @written = written
      @skills = skills
      @mounts = mounts
      @approval = approval
      @chat = chat
      @requested_languages = languages
      node = NodeInstallation.current if languages.include?(:javascript)
      @packages = Packages.new(sandbox: -> { isolated(self.sandbox) }, cache_dir: package_cache_dir, node:, **packages)
    end

    # Returns the default Sandbox calls run in. Raises ConfigurationError
    # when there is none.
    def sandbox
      current = resolve(@sandbox.is_a?(Proc) ? @sandbox.call : @sandbox)
      current || raise(ConfigurationError, 'Code execution needs a sandbox. Set config.sandbox to a sandbox class.')
    end

    # Returns the names of the sandboxes the model may ask for, leaving out
    # those that cannot run on this machine.
    #
    #   chat.tools[:run_code].escalations # => ["workspace", "online"]
    def escalations
      escalation_sandboxes.keys
    end

    # Returns what the sandbox named +name+ allows, in one sentence, for the
    # person approving a call that asks for it, or +nil+ for an unknown
    # name.
    #
    #   chat.tools[:run_code].summary("workspace")
    #   # => "Starts in /srv/app. Can change /srv/app. No network access. Stops after 300 seconds."
    def summary(name)
      sandbox = escalation_sandboxes[name.to_s]
      describe_sandbox(sandbox) if sandbox
    end

    # Returns the directories mounted read-only in each run directory, keyed
    # by their path there. Raises ArgumentError for a path outside the run
    # directory or a directory that does not exist.
    def mounts
      mounts = @mounts.is_a?(Proc) ? @mounts.call : @mounts
      raise ArgumentError, 'mounts: takes a Hash or a Proc that returns one' unless mounts.is_a?(Hash)

      mounts.to_h do |name, directory|
        directory = File.expand_path(directory)
        raise ArgumentError, "#{directory} is not a directory" unless File.directory?(directory)

        [self.class.mount_name(name), File.realpath(directory)]
      end
    end

    # Returns whether +tool_call+ asks for a sandbox wider than the default:
    # such a call waits for Chat#approve, every time.
    def requires_approval?(tool_call = nil)
      !escalation_for(tool_call).nil?
    end

    # Returns the languages the model may use: those requested that the
    # sandbox can run. Raises ConfigurationError when it can run none.
    def languages
      (@languages ||= {}.compare_by_identity)[sandbox_key] ||= begin
        options = { env: @packages.base_env(Dir.tmpdir), readable: @packages.runtimes,
                    denied: @packages.denied }
        available = @requested_languages.select do |name|
          self.class.available?(sandbox_key, sandbox, Language[name], **options)
        end
        raise ConfigurationError, "The sandbox cannot run #{@requested_languages.join(', ')}" if available.empty?

        available
      end
    end

    # Returns the description the model sees, naming only the languages
    # the sandbox can run and the sandboxes it may ask for.
    def description
      [
        "Runs #{language_list} code in a sandbox and returns its exit code, output, and the files it writes.",
        *files_note,
        mounts_note,
        packages_note,
        directory_note(sandbox),
        describe_sandbox(sandbox, directory: false),
        escalations_note
      ].compact.join(' ')
    end

    # Returns the JSON Schema of the arguments: +language+ and +code+,
    # +files+ when runs copy in the chat's files, and +sandbox+ and
    # +reason+ when the model may ask for another sandbox.
    def parameters_schema
      properties = {
        'language' => { 'type' => 'string', 'enum' => languages.map(&:to_s),
                        'description' => 'The language the code is written in' },
        'code' => { 'type' => 'string', 'description' => 'The complete program to run' }
      }
      properties['files'] = FILES_PROPERTY if copies_files?
      properties.merge!(escalation_properties) if escalations.any?
      { 'type' => 'object', 'properties' => properties, 'required' => properties.keys,
        'additionalProperties' => false, 'strict' => true }
    end

    # Runs +code+ written in +language+ and returns its report, followed by
    # the files it wrote as Attachments. +files+ names the chat's files to
    # copy into the run directory, for a store without a folder. With
    # +sandbox+, runs in that sandbox only when the chat recorded an
    # approval for +tool_call+.
    def execute(language:, code:, sandbox: nil, reason: nil, files: nil, tool_call: nil) # rubocop:disable Lint/UnusedMethodArgument
      language = language.to_s.downcase.to_sym
      unless languages.include?(language)
        return { error: "Unsupported language #{language}. Use one of: #{languages.join(', ')}" }
      end

      runner, error = runner_for(sandbox, code, tool_call)
      return { error: } if error

      store = @file_store.call
      Workspace.open(attachments: store.nil?) do |workspace|
        options = { runner:, name: sandbox, tool_call:, store: }
        root = store&.local_root
        next run_in_place(Language[language], code, workspace, root:, **options) if root

        run(Language[language], code, workspace, names: files, **options)
      end
    rescue Workspace::Unavailable => e
      { error: e.message }
    end

    private

    def runner_for(name, code, tool_call)
      return [sandbox, nil] if name.nil?

      escalation = escalation_sandboxes[name.to_s]
      return [nil, "Unknown sandbox #{name}. Use one of: #{escalations.join(', ')}"] unless escalation
      return [nil, "Running in the #{name} sandbox was not approved."] unless approved?(tool_call, name, code)

      [resolve(escalation), nil]
    end

    def approved?(tool_call, name, code)
      return false unless tool_call && escalation_for(tool_call) == name.to_s

      arguments = tool_call.arguments.to_h.transform_keys(&:to_s)
      arguments['code'] == code && @approval.call(tool_call) == true
    end

    def escalation_for(tool_call)
      return unless tool_call.respond_to?(:arguments) && tool_call.arguments.respond_to?(:to_h)

      name = tool_call.arguments.to_h.transform_keys(&:to_s)['sandbox']
      name.to_s if name && escalation_sandboxes.key?(name.to_s)
    end

    def escalation_sandboxes
      @escalation_sandboxes ||= @escalate_to.select { |_, sandbox| resolve(sandbox).supported? }
    end

    def resolve(value)
      config = @config.is_a?(Proc) ? @config.call : @config
      Sandbox.resolve(value, backend: (config || RubyLLM.config).sandbox_backend)
    end

    def sandbox_key
      value = @sandbox.is_a?(Proc) ? @sandbox.call : @sandbox
      value.is_a?(String) ? Sandbox.constant(value) : value
    end

    def isolated(runner)
      runner.respond_to?(:isolated) ? runner.isolated : runner
    end

    def escalation_properties
      {
        'sandbox' => { 'type' => %w[string null], 'enum' => [*escalations, nil],
                       'description' => 'null for the default sandbox, or a sandbox to ask the user for' },
        'reason' => { 'type' => %w[string null],
                      'description' => 'Why the code needs that sandbox. The user reads it before deciding' }
      }
    end

    def run(language, code, workspace, runner:, name:, tool_call:, store:, names:)
      all_mounts = mounts.merge(@skills.call)
      copied = if store
                 workspace.copy_files(store, stored_files(store, names, all_mounts.keys))
               else
                 workspace.copy_in(@attachments.call)
               end
      mounted = workspace.mount(all_mounts)
      script = prepare(workspace, language, code)
      instrument(language, runner, name, tool_call) do |event|
        result = run_in_sandbox(runner, language.command(script), workspace, readable: mounted)
        files, skipped = workspace.outputs(max_files: MAX_FILES, max_size: MAX_FILE_SIZE, unchanged: copied)
        record(event, result, files.map(&:filename))
        next save(store, result, files, skipped) if store

        files.empty? ? report(result, files, skipped) : [report(result, files, skipped), *files]
      end
    end

    # Runs in the store's own folder: the code reads and writes the files in
    # place, and each file it creates or changes is passed to +written+.
    def run_in_place(language, code, workspace, root:, runner:, name:, tool_call:, store:)
      mounted = workspace.mount(mounts.merge(@skills.call), into: root)
      script = prepare(workspace, language, code)
      before = snapshot(store)
      instrument(language, runner, name, tool_call) do |event|
        result = run_in_sandbox(runner, language.command(script), workspace, readable: mounted, directory: root)
        changed = store.list.reject { |file| before[file.path] == [file.byte_size, file.updated_at] }
        changed.each { |file| @written.call(file) }
        record(event, result, changed.map(&:path))
        unmounted = workspace.unmounted
        report(result, changed.map(&:path), [], unmounted: (unmounted_note(unmounted) if unmounted.any?))
      end
    end

    def prepare(workspace, language, code)
      workspace.write_source(language, code).tap do
        workspace.link_packages(@packages.node_modules) if language.name == :javascript && @packages.node_modules
      end
    end

    def snapshot(store)
      store.list.to_h { |file| [file.path, [file.byte_size, file.updated_at]] }
    end

    # Returns the StoredFiles +names+ asks for: each a file, or a folder
    # standing for every file in it. Raises Workspace::Unavailable for a
    # name with no file, or one under a read-only folder.
    def stored_files(store, names, read_only)
      Array(names).flat_map { |name| stored_files_at(store, name, read_only) }.uniq(&:path)
    end

    def stored_files_at(store, name, read_only)
      path = FileStore.path(name)
      mount = read_only.find { |folder| FileStore.inside?(path, folder) || FileStore.inside?(folder, path) }
      raise Workspace::Unavailable, "#{name} is in the read-only folder #{mount}, which every run has" if mount

      files = [store.find(path)].compact
      files = store.list(path) if files.empty?
      raise Workspace::Unavailable, "No file or folder #{name} in this chat's files. See list_files." if files.empty?

      files
    rescue ArgumentError => e
      raise Workspace::Unavailable, e.message
    end

    def copies_files?
      store = @file_store.call
      !store.nil? && store.local_root.nil?
    end

    # Saves what the run wrote. A file the store has no room for is left
    # out, and the report names it with the store's reason, so the model
    # reads why instead of the reply failing.
    def save(store, result, files, skipped)
      saved = []
      unsaved = []
      reason = nil
      files.each do |file|
        saved << store.write(file.filename, file.content).tap { |stored| @written.call(stored) }
      rescue FileStoreFullError => e
        unsaved << file.filename
        reason ||= e.message
      end
      report(result, saved.map(&:path), skipped, unsaved_files: (unsaved if unsaved.any?), files_error: reason)
    end

    def run_in_sandbox(runner, command, workspace, readable:, directory: workspace.directory)
      runner.run(*command,
                 readable: [*@packages.readable, *@packages.resolver_config(setting(runner, :network)), *readable,
                            workspace.source, workspace.inputs],
                 denied: @packages.denied,
                 writable: [directory, workspace.home, workspace.tmp],
                 timeout: timeout_for(runner), directory: (directory unless setting(runner, :directory)),
                 env: @packages.env(workspace.home, workspace.tmp).merge(RUN_DIR => directory))
    end

    def setting(runner, name)
      runner.public_send(name) if runner.respond_to?(name)
    end

    def timeout_for(runner)
      setting(runner, :timeout) || Sandbox::DEFAULT_TIMEOUT
    end

    def instrument(language, runner, name, tool_call)
      payload = { chat: @chat, tool_call_id: tool_call&.id, tool_name: self.name, language: language.name,
                  sandbox: name&.to_s, timeout: timeout_for(runner), network: setting(runner, :network) }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      config = @config.is_a?(Proc) ? @config.call : @config
      RubyLLM.instrument('code_execution.ruby_llm', payload, config:) do |event|
        yield event
      ensure
        event[:duration] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end
    end

    def record(event, result, paths)
      event[:exit_code] = result.exit_code
      event[:timed_out] = result.timed_out?
      event[:blocked_hosts] = Array(result.blocked) if result.respond_to?(:blocked)
      event[:cpu_time] = result.cpu_time if result.respond_to?(:cpu_time)
      event[:limit_exceeded] = result.limit_exceeded if result.respond_to?(:limit_exceeded)
      event[:files] = paths
    end

    def report(result, files, skipped, **notes)
      blocked = Array(result.blocked) if result.respond_to?(:blocked)
      {
        exit_code: result.exit_code,
        stdout: truncate(result.stdout),
        stderr: truncate(result.stderr),
        error: run_error(result),
        blocked_hosts: (blocked if blocked&.any?),
        files: (files.map { |file| file.is_a?(String) ? file : file.filename } if files.any?),
        skipped_files: (skipped if skipped.any?),
        **notes
      }.compact.to_json
    end

    def unmounted_note(paths)
      "The read-only folders #{paths.join(', ')} were not mounted, because this chat's files have something " \
        'of their own at those paths: the code saw that instead.'
    end

    def run_error(result)
      return 'The code ran past its time limit and was stopped' if result.timed_out?

      limit = result.limit_exceeded if result.respond_to?(:limit_exceeded)
      LIMIT_ERRORS[limit] if limit
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

    def files_note
      store = @file_store.call
      if store&.local_root
        ["Code runs in the folder that holds this chat's files, the ones list_files shows, and reads them " \
         'there by their paths.',
         'What it writes, changes, or deletes there changes the chat\'s files at once, for read_file and later runs.']
      elsif store
        ['Each call gets a new empty run directory. To use files from this chat\'s files, the ones list_files ' \
         'shows, name them in files and they are copied in at the same paths; a folder copies everything in it.',
         'Files the code writes or changes there are saved to the chat\'s files when it ends, where read_file ' \
         'and later runs find them. Deleting a file there does not delete it from the chat\'s files.']
      else
        ['Each call gets a new empty run directory, and nothing carries over between calls.',
         "Files attached to the conversation, and files earlier calls returned, are in ./#{Workspace::ATTACHMENTS} " \
         '(read-only). Write files to the run directory to return them to the user.']
      end
    end

    def mounts_note
      names = mounts.keys
      "These folders are available read-only: #{names.map { |name| "./#{name}" }.join(', ')}." if names.any?
    end

    def packages_note
      notes = []
      gems = @packages.gem_names
      python = @packages.python_names
      npm = @packages.npm_names
      notes << "Ruby #{RUBY_VERSION} has these gems: #{gems.join(', ')}." if gems.any?
      notes << "Python has these packages: #{python.join(', ')}." if python.any?
      notes << "JavaScript has these npm packages: #{npm.join(', ')}." if npm.any?
      notes.join(' ') unless notes.empty?
    end

    def directory_note(runner)
      directory = setting(runner, :directory)
      return unless directory

      "Code starts in #{File.expand_path(directory)}, not in the run directory: read the conversation's files " \
        "and write files to return under $#{RUN_DIR}."
    end

    def escalations_note
      return if escalations.empty?

      sandboxes = escalation_sandboxes.map do |name, sandbox|
        runner = resolve(sandbox)
        "#{name}: #{[directory_note(runner), describe_sandbox(runner, directory: false)].compact.join(' ')}"
      end
      'When the code needs more than this sandbox allows, set sandbox to one of these and explain why in reason. ' \
        'The user approves each such call, and the next call runs in the default sandbox again. ' \
        "#{sandboxes.join(' ')}"
    end

    def describe_sandbox(sandbox, directory: true)
      runner = sandbox.respond_to?(:run) ? sandbox : resolve(sandbox)
      [(directory_sentence(runner) if directory), paths_sentence('Can read', setting(runner, :readable)),
       paths_sentence('Can change', setting(runner, :writable)), network_sentence(setting(runner, :network)),
       limits_sentence(setting(runner, :limits)), "Stops after #{timeout_for(runner)} seconds."].compact.join(' ')
    end

    def directory_sentence(runner)
      directory = setting(runner, :directory)
      "Starts in #{File.expand_path(directory)}." if directory
    end

    def paths_sentence(label, paths)
      paths = Array(paths).map { |path| File.expand_path(path) }
      "#{label} #{paths.join(', ')}." if paths.any?
    end

    def limits_sentence(limits)
      limits = limits.to_h
      seconds = limits[:cpu_time].to_f.ceil if limits[:cpu_time]
      parts = [("#{seconds} #{seconds == 1 ? 'second' : 'seconds'} of CPU time" if seconds),
               ("#{(limits[:memory].to_i / (1024.0**2)).ceil} MB of memory" if limits[:memory]),
               ("#{limits[:processes]} processes at once" if limits[:processes])].compact
      "Each process may use #{parts.join(' and ')}." if parts.any?
    end

    def network_sentence(network)
      case network
      when true then 'Can reach the network.'
      when Hash then "Can reach only #{Array(network[:allow]).join(', ')}."
      else 'No network access.'
      end
    end
  end
end
