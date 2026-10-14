# frozen_string_literal: true

module RubyLLM
  module Sandbox
    # Runs commands with an MXC::Sandbox class or instance from the mxc gem:
    # Bubblewrap on Linux, Seatbelt on macOS, and process containers on
    # Windows. Each run starts from a fresh copy of the sandbox's policy and
    # adds only what RubyLLM passes for that run.
    class MXC # :nodoc:
      attr_reader :policy

      def initialize(policy)
        @policy = policy
      end

      def supported?
        sandbox.supported?
      end

      def reason
        availability = sandbox.availability
        return if availability.supported?

        [availability.reason, availability.remediation].compact.join(' ')
      end

      def readable = sandbox.readable
      def writable = sandbox.writable
      def network = sandbox.network
      def directory = sandbox.directory
      def timeout = sandbox.timeout

      # Returns a runner for a sandbox with none of this one's access, on
      # the same backend, for RubyLLM's own package installs.
      def isolated
        self.class.new(::MXC::Sandbox.new(backend: sandbox.backend))
      end

      def run(*command, timeout:, readable: [], writable: [], denied: [], directory: nil, env: {}, network: nil)
        run = sandbox.with_readable(*readable).with_writable(*writable).with_denied(*denied).with_timeout(timeout)
        run.with_directory(directory) if run.directory.nil? && directory
        run.with_env(env.reject { |name, _| run.env.key?(name) })
        apply_network(run, network)
        run.run(*command)
      end

      def inspect
        "#<#{self.class.name} #{sandbox.inspect}>"
      end

      private

      def sandbox
        @policy.is_a?(Class) ? @policy.new : @policy.dup
      end

      def apply_network(run, network)
        return if network.nil?

        network.is_a?(Hash) ? run.with_network(**network) : run.with_network(network)
      end
    end
  end
end
