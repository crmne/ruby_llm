# frozen_string_literal: true

module RubyLLM
  module Sandbox
    # Runs commands with an MXC::Sandbox class or instance from the mxc gem:
    # Bubblewrap on Linux, unless Configuration#sandbox_backend or the
    # sandbox asks for Landlock, Seatbelt on macOS, and process containers
    # on Windows. Each run starts from a fresh copy of the sandbox's policy
    # and adds only what RubyLLM passes for that run.
    class MXC # :nodoc:
      DOCS = 'https://rubyllm.com/sandboxes/#running-on-landlock'
      NAMESPACES = /namespace/i
      BUBBLEWRAP_REMEDIATION =
        'Allow unprivileged user namespaces for Bubblewrap: on Ubuntu 23.10 and later, including 24.04, ' \
        'give bwrap an AppArmor profile that allows userns, or, host-wide and weaker, run ' \
        'sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0; on kernels with ' \
        'kernel.unprivileged_userns_clone, set it to 1. In Docker, run with a seccomp profile that allows ' \
        'namespaces: https://crmne.github.io/mxc/running-in-docker/. ' \
        'See https://rubyllm.com/sandboxes/#running-on-linux'
      LANDLOCK_OPT_IN = 'Or set config.sandbox_backend = :landlock to run on Landlock, which isolates less ' \
                        "and has no network access: #{DOCS}".freeze

      attr_reader :policy

      def initialize(policy, backend: :bubblewrap)
        @policy = policy
        @backend = backend
      end

      def supported?
        sandbox.supported?
      end

      def reason
        current = sandbox
        availability = current.availability
        return if availability.supported?

        [availability.reason, *remediation(current.backend, availability)].compact.join(' ')
      end

      def backend = sandbox.backend
      def readable = sandbox.readable
      def writable = sandbox.writable
      def network = sandbox.network
      def directory = sandbox.directory
      def timeout = sandbox.timeout
      def limits = sandbox.respond_to?(:limits) ? sandbox.limits : {}

      # Returns a runner for a sandbox with none of this one's access, on
      # the same backend, for RubyLLM's own package installs.
      def isolated
        self.class.new(::MXC::Sandbox.new(backend: sandbox.backend), backend: @backend)
      end

      def run(*command, timeout:, readable: [], writable: [], denied: [], directory: nil, env: {}, network: nil, &)
        run = sandbox.with_readable(*readable).with_writable(*writable).with_denied(*denied).with_timeout(timeout)
        run.with_directory(directory) if run.directory.nil? && directory
        run.with_env(env.reject { |name, _| run.env.key?(name) })
        apply_network(run, network)
        run = Landlock.policy(run) if run.backend == :landlock
        block_given? ? run_by_line(run, command, &) : run.run(*command)
      end

      def inspect
        "#<#{self.class.name} #{sandbox.inspect}>"
      end

      private

      def run_by_line(run, command)
        pending = Hash.new { |buffers, stream| buffers[stream] = String.new(encoding: Encoding::BINARY) }
        result = run.run(*command) do |chunk|
          buffer = pending[chunk.stream] << chunk.content.b
          while (newline = buffer.index("\n"))
            yield text(buffer.slice!(0..newline))
          end
        end
        pending.each_value { |rest| yield text(rest) unless rest.empty? }
        result
      end

      def text(bytes)
        bytes.force_encoding(Encoding::UTF_8).scrub
      end

      def sandbox
        sandbox = @policy.is_a?(Class) ? @policy.new : @policy.dup
        sandbox.backend == :auto && linux? ? sandbox.with_backend(@backend) : sandbox
      end

      def remediation(backend, availability)
        return availability.remediation unless backend == :bubblewrap

        namespaces = [availability.reason, availability.remediation].join(' ').match?(NAMESPACES)
        [namespaces ? BUBBLEWRAP_REMEDIATION : availability.remediation, LANDLOCK_OPT_IN]
      end

      def linux?
        RUBY_PLATFORM.include?('linux')
      end

      def apply_network(run, network)
        return if network.nil?

        network.is_a?(Hash) ? run.with_network(**network) : run.with_network(network)
      end
    end
  end
end
