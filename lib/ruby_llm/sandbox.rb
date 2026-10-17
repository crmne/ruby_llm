# frozen_string_literal: true

module RubyLLM
  # A sandbox runs commands RubyLLM did not write, such as the code a model
  # sends to Chat#with_code_execution, and holds the whole policy for them:
  # what they may read and write, which hosts they reach, where they start,
  # and how long they run. Define one as an MXC::Sandbox class from the mxc
  # gem:
  #
  #   class ReadOnlySandbox < MXC::Sandbox
  #     timeout 120
  #   end
  #
  #   class WorkspaceSandbox < MXC::Sandbox
  #     directory Rails.root.join("storage/workspace")
  #     writable Rails.root.join("storage/workspace")
  #     timeout 300
  #   end
  #
  #   RubyLLM.configure do |config|
  #     config.sandbox = "ReadOnlySandbox"
  #   end
  #
  # A String names the class and is looked up whenever a chat needs it,
  # so in Rails the classes live in +app/sandboxes+, autoload, and reload
  # like the rest of the application.
  #
  # A sandbox may be an MXC::Sandbox class or instance, or any other class
  # or object whose instances answer two methods:
  #
  #   class RemoteSandbox
  #     def supported?
  #       true
  #     end
  #
  #     def run(*command, timeout:, readable: [], writable: [], denied: [], directory: nil, env: {}, network: nil)
  #       # Runs +command+ and returns an object answering stdout, stderr,
  #       # exit_code, and timed_out?
  #     end
  #   end
  #
  # +run+ takes the command like Kernel#system: one String for the shell,
  # or a program and its arguments. The keywords are what RubyLLM adds to
  # the sandbox's own policy for one run: +readable+ and +writable+ paths
  # holding the run's files, +denied+ paths it must not see, even inside
  # readable ones, the +directory+ to start in when the sandbox has none of
  # its own, and +env+, the environment the run's languages and packages
  # need. +timeout+ is the sandbox's own, or 120 seconds when it answers
  # +timeout+ with +nil+ or not at all. +network+ is +nil+ for the
  # sandbox's own access; RubyLLM passes <tt>{ allow: [...] }</tt> only to
  # install declared packages from their registries. The result may also
  # answer +blocked+, the hosts the network policy refused. A sandbox may
  # answer +reason+, which RubyLLM adds to the error it raises when
  # #supported? is false, and +readable+, +writable+, +network+,
  # +directory+, and +timeout+, which describe it to the model and to the
  # person approving an escalation.
  module Sandbox
    # Seconds a run may take when the sandbox sets no timeout.
    DEFAULT_TIMEOUT = 120

    # The values Configuration#sandbox_backend accepts.
    BACKENDS = %i[bubblewrap landlock].freeze

    class << self
      # Returns a runner for the sandbox +value+ describes, or +nil+ for
      # none. A String names the sandbox class, looked up on each call.
      # An MXC::Sandbox runs on +backend+ on Linux unless it names its own.
      #
      # Raises ConfigurationError for a value that is not a sandbox, or for
      # a backend other than those in BACKENDS.
      def resolve(value, backend: RubyLLM.config.sandbox_backend) # :nodoc:
        return if value.nil?

        value = constant(value) if value.is_a?(String)
        return MXC.new(value, backend: backend_name(backend)) if mxc?(value)

        instance = value.is_a?(Class) ? value.new : value
        return instance if instance.respond_to?(:run) && instance.respond_to?(:supported?)

        raise ConfigurationError,
              "A sandbox is an MXC::Sandbox class or an object answering supported? and run, got #{value.inspect}"
      end

      # Returns the name the model uses for +value+: its class name without
      # a +Sandbox+ suffix, in snake case, so WorkspaceSandbox is
      # +workspace+.
      #
      # Raises ArgumentError when the class has no name.
      def name_for(value) # :nodoc:
        base = class_name(value).to_s.split('::').last.to_s.delete_suffix('Sandbox')
        if base.empty?
          raise ArgumentError, "Name the sandbox #{value.inspect} with a Hash: escalate_to: { name => sandbox }"
        end

        base.gsub(/([A-Z\d])([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      end

      # Raises ConfigurationError unless +sandbox+ can run on this machine.
      def verify(sandbox) # :nodoc:
        return if sandbox.nil? || sandbox.supported?

        reason = sandbox.reason if sandbox.respond_to?(:reason)
        raise ConfigurationError, ['The configured sandbox cannot run on this machine.', reason].compact.join(' ')
      end

      # Returns the class a String names. Raises ConfigurationError when
      # nothing by that name is defined.
      def constant(name) # :nodoc:
        Object.const_get(name)
      rescue NameError
        raise ConfigurationError, "The sandbox #{name} is not defined"
      end

      private

      def backend_name(backend)
        name = backend.respond_to?(:to_sym) ? backend.to_sym : backend
        return name if BACKENDS.include?(name)

        raise ConfigurationError,
              "config.sandbox_backend is #{BACKENDS.map(&:inspect).join(' or ')}, got #{backend.inspect}"
      end

      def class_name(value)
        return value if value.is_a?(String)

        (value.is_a?(Class) ? value : value.class).name
      end

      def mxc?(value)
        defined?(::MXC::Sandbox) && (value.is_a?(::MXC::Sandbox) || (value.is_a?(Class) && value <= ::MXC::Sandbox))
      end
    end
  end
end
