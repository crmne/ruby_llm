# frozen_string_literal: true

module ReactorHelpers
  # Runs the block in an Async reactor. Real I/O under the reactor makes Ruby
  # warn once per process that IO::Buffer is experimental, so the warning is
  # silenced while it runs.
  def in_reactor(&)
    skip 'async runs on MRI' unless RUBY_ENGINE == 'ruby'
    require 'async'
    experimental = Warning[:experimental]
    Warning[:experimental] = false
    Sync(&)
  ensure
    Warning[:experimental] = experimental unless experimental.nil?
  end
end

RSpec.configure do |config|
  config.include ReactorHelpers
end
