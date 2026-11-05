# frozen_string_literal: true

module RubyLLM
  class Chat
    # Attributes every provider attempt a chat's operations make, including
    # the tools and converters they run, to the owner set with
    # Chat#with_owner, through the same fiber storage RubyLLM.with_owner
    # uses. A chat without an owner leaves the surrounding one in place.
    module Ownership # :nodoc:
      Rescuable::OPERATIONS.each do |operation|
        define_method(operation) do |*args, **kwargs, &block|
          Accounting::Usage.owned_by(owner) { super(*args, **kwargs, &block) }
        end
      end
    end
  end
end
