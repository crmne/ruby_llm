# frozen_string_literal: true

module RubyLLM
  module Support
    # Keeps chats, agents, and <tt>acts_as_chat</tt> records Enumerable over
    # their messages through RubyLLM 2.x. Their +each+ is deprecated, and
    # the Enumerable methods built on it with it: iterate +messages+
    # instead. RubyLLM 3.0 removes them.
    module DeprecatedEnumerable # :nodoc:
      include Enumerable
    end
  end
end
