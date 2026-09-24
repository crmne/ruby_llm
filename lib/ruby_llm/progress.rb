# frozen_string_literal: true

module RubyLLM
  # Progress a tool or an MCP server reports while it works. A Tool reports
  # it with Tool#progress; Chat#after_tool_progress and MCP.after_progress
  # callbacks receive it.
  #
  #   chat.after_tool_progress do |tool_call, progress|
  #     puts "#{tool_call.name}: #{progress.message} #{progress.value}/#{progress.total}"
  #   end
  #
  class Progress
    include Support::Inspectable

    # How much work is done, or +nil+ when only a message was reported. It
    # only grows, but its unit is the reporter's.
    attr_reader :value

    # How much work there is in total, or +nil+ when the reporter does not
    # know.
    attr_reader :total

    # What the tool or server is doing, or +nil+.
    attr_reader :message

    def initialize(value: nil, total: nil, message: nil) # :nodoc:
      @value = value
      @total = total
      @message = message
    end

    # Returns the share of work done, from 0.0 to 1.0, or +nil+ without a
    # value and a total.
    def fraction
      value.to_f / total if value && total&.positive?
    end

    private

    def inspect_attributes
      { value:, total:, message: }
    end
  end
end
