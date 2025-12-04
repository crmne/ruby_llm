# frozen_string_literal: true

module RubyLLM
  # Optional instrumentation if ActiveSupport::Notifications is defined
  module Instrumentation
    def instrument(name, payload = {})
      if defined?(ActiveSupport::Notifications)
        ActiveSupport::Notifications.instrument(name, payload) { yield payload }
      else
        yield
      end
    end
    module_function :instrument
  end
end
