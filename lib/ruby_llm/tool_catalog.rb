# frozen_string_literal: true

require 'set'

module RubyLLM
  # Pool of deferred tools for a Chat. Anthropic's +defer_loading: true+
  # keeps them out of the model's visible menu; when the native
  # +tool_search_tool_bm25+ primitive loads one, +promote+ moves it into the
  # active tool list so the normal tool-dispatch path can execute it.
  class ToolCatalog
    attr_reader :deferred_tools, :loaded_tools

    def initialize
      @deferred_tools = {}
      @loaded_tools = Set.new
    end

    def empty?
      @deferred_tools.empty?
    end

    def any?
      !empty?
    end

    def add(tool)
      @deferred_tools[tool.name.to_sym] = tool
      self
    end

    def available
      @deferred_tools.except(*@loaded_tools)
    end

    def promote(name)
      sym = name.to_sym
      tool = @deferred_tools[sym]
      return nil unless tool

      @loaded_tools << sym
      tool
    end

    def inspect
      "#<#{self.class} deferred=#{@deferred_tools.size} loaded=#{@loaded_tools.size}>"
    end
  end
end
