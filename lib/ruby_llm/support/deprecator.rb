# frozen_string_literal: true

module RubyLLM
  module Support # :nodoc:
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
  end
end
