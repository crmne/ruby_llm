# frozen_string_literal: true

module RubyLLM
  # A sandbox runs commands RubyLLM did not write, such as the code a model
  # sends to Chat#with_code_execution, where they cannot read your project,
  # your home directory, or your secrets. Set one in the configuration:
  #
  #   RubyLLM.configure do |config|
  #     config.sandbox = :mxc
  #   end
  #
  # +:mxc+ uses the built-in sandbox on the mxc gem. Any other object that
  # answers two methods works too:
  #
  #   class RemoteSandbox
  #     def supported?
  #       true
  #     end
  #
  #     def run(*command, readable: [], writable: [], network: false, timeout:, directory: nil, env: {})
  #       # Runs +command+ and returns an object answering stdout, stderr,
  #       # exit_code, and timed_out?
  #     end
  #   end
  #
  # +run+ takes the command like Kernel#system: one String for the shell,
  # or a program and its arguments. +readable+ and +writable+ are paths on
  # this machine the command may read, or read and change. +network+ is
  # +false+, +true+, or <tt>{ allow: ["pypi.org"] }</tt>. +directory+ is
  # where the command starts and +env+ the only environment variables it
  # gets. The result may also answer +blocked+, the hosts the network
  # policy refused. A sandbox may answer +reason+, which RubyLLM adds to the
  # error it raises when #supported? is false.
  module Sandbox
    class << self
      # Returns the sandbox +value+ names: +nil+ for none, the built-in
      # sandbox for +:mxc+, or +value+ itself when it answers +run+.
      #
      # Raises ConfigurationError for any other value, and for +:mxc+ when
      # the mxc gem is not installed.
      def resolve(value) # :nodoc:
        case value
        when nil then nil
        when :mxc, 'mxc' then mxc
        else
          return value if value.respond_to?(:run) && value.respond_to?(:supported?)

          raise ConfigurationError,
                "config.sandbox must be :mxc or an object answering supported? and run, got #{value.inspect}"
        end
      end

      # Raises ConfigurationError unless +sandbox+ can run on this machine.
      def verify(sandbox) # :nodoc:
        return if sandbox.nil? || sandbox.supported?

        reason = sandbox.reason if sandbox.respond_to?(:reason)
        raise ConfigurationError, ['The configured sandbox cannot run on this machine.', reason].compact.join(' ')
      end

      private

      def mxc
        @mxc ||= begin
          require 'mxc'
          MXC.new
        rescue LoadError
          raise ConfigurationError, 'config.sandbox = :mxc needs the mxc gem. Add `gem "mxc"` to your Gemfile.'
        end
      end
    end
  end
end
