# frozen_string_literal: true

module RubyLLM
  module Sandbox
    # The built-in sandbox, set with <tt>config.sandbox = :mxc</tt>. It runs
    # each command with the mxc gem: Bubblewrap on Linux, Seatbelt on macOS,
    # and process containers on Windows.
    class MXC
      # Returns whether mxc can start a sandbox on this machine.
      def supported?
        ::MXC.supported?
      end

      # Returns why mxc cannot start a sandbox here and how to fix it, or
      # +nil+ when it can.
      def reason
        availability = ::MXC.availability
        return if availability.supported?

        [availability.reason, availability.remediation].compact.join(' ')
      end

      # Runs +command+ in a new mxc sandbox and returns its MXC::Result. See
      # Sandbox for the arguments.
      def run(*command, timeout:, readable: [], writable: [], network: false, directory: nil, env: {})
        ::MXC::Sandbox.new(readable:, writable:, network:, timeout:, directory:, env:).run(*command)
      end
    end
  end
end
