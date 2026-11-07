# frozen_string_literal: true

module RubyLLM
  class MCP
    # A server's question to the person, the same Question a tool asks
    # with Tool#ask, under its 2.1 name.
    InputRequest = RubyLLM::Question
  end
end
