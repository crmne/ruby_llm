# frozen_string_literal: true

# The backend the sandbox specs run on: Bubblewrap unless
# RUBYLLM_SANDBOX_BACKEND names another, as CI does to cover Landlock.
# With RUBYLLM_REQUIRE_SANDBOX=true, a sandbox that cannot run fails the
# specs instead of skipping them.
module SandboxBackend
  module_function

  def name
    ENV.fetch('RUBYLLM_SANDBOX_BACKEND', 'bubblewrap').to_sym
  end

  def landlock?
    name == :landlock
  end

  def supported?
    require 'mxc'
    sandbox = RubyLLM::Sandbox.resolve(MXC::Sandbox, backend: name)
    return true if sandbox.supported?
    raise "The #{name} sandbox cannot run: #{sandbox.reason}" if ENV['RUBYLLM_REQUIRE_SANDBOX'] == 'true'

    false
  rescue LoadError
    raise if ENV['RUBYLLM_REQUIRE_SANDBOX'] == 'true'

    false
  end

  def network_policy?
    !landlock? && supported? && MXC.supports?(:network_policy)
  end
end

RubyLLM.configure { |config| config.sandbox_backend = SandboxBackend.name }
