# frozen_string_literal: true

module RubyLLM
  module Support
    # The +rescue_from+ macro Agent, Tool, and MCP share: handlers named
    # with +with:+ or given as a block, searched in reverse declaration
    # order from the class up through its ancestors when an exception is
    # raised, and run on the instance whose work raised.
    module Rescuable # :nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end

      # The class side of Rescuable.
      module ClassMethods # :nodoc:
        def rescue_from(*exception_classes, with: nil, &block)
          raise ArgumentError, 'rescue_from needs a handler: pass with: or a block' unless with || block
          raise ArgumentError, 'rescue_from takes with: or a block, not both' if with && block

          exception_classes.flatten.each do |exception_class|
            rescue_handlers << [rescue_handler_key(exception_class), with || block]
          end
        end

        def rescue_handlers
          @rescue_handlers ||= []
        end

        def rescue_handler_for(exception)
          rescue_handlers.reverse_each do |class_name, handler|
            exception_class = rescue_handler_class(class_name)
            return handler if exception_class && exception.is_a?(exception_class)
          end
          superclass.rescue_handler_for(exception) if superclass.respond_to?(:rescue_handler_for)
        end

        def rescue_handlers?
          rescue_handlers.any? || (superclass.respond_to?(:rescue_handlers?) && superclass.rescue_handlers?)
        end

        private

        def rescue_handler_key(exception_class)
          case exception_class
          when ->(klass) { klass.is_a?(Module) && !(klass.is_a?(Class) && (klass <=> StandardError).nil?) }
            exception_class.name || exception_class
          when String then exception_class
          else raise ArgumentError, "#{exception_class.inspect} is not a StandardError class or its name"
          end
        end

        def rescue_handler_class(class_name)
          return class_name if class_name.is_a?(Module)

          Object.const_get(class_name)
        rescue NameError
          nil
        end
      end

      # Runs the ::rescue_from handler matching +exception+ and returns its
      # value, or re-raises when no handler matches.
      def rescue_with_handler(exception)
        handler = self.class.rescue_handler_for(exception)
        raise exception unless handler

        run_rescue_handler(handler, exception)
      end

      private

      def run_rescue_handler(handler, exception)
        return instance_exec(exception, &handler) unless handler.is_a?(Symbol)

        handler_method = method(handler)
        handler_method.arity.zero? ? handler_method.call : handler_method.call(exception)
      end
    end
  end
end
