# frozen_string_literal: true

module RubyLLM
  class Deprecator # :nodoc:
    def warn(message)
      case RubyLLM.config.deprecation_behavior
      when :silence
        nil
      when :raise
        raise DeprecationError, message
      else
        RubyLLM.logger.warn(message)
      end
    end

    def deprecate(name, replacement:, removal:)
      warn("#{name} is deprecated and will be removed in RubyLLM #{removal}. Use #{replacement} instead.")
    end
  end

  # Raised when a deprecated API is used and
  # Configuration#deprecation_behavior is +:raise+. With the default
  # +:warn+, deprecations are logged instead.
  #
  #   RubyLLM.configure do |config|
  #     config.deprecation_behavior = :raise
  #   end
  class DeprecationError < StandardError; end
end
