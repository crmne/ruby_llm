# frozen_string_literal: true

module RubyLLM
  # A RequestShape describes a conversation request as the provider received
  # it, without its contents: each turn's role and parts with their sizes,
  # the tools on offer, the thinking settings, and the problems RubyLLM finds
  # in it, such as a part with no data or a tool call with no result. Read it
  # from Error#request_shape when a provider rejects a request without saying
  # what is wrong with it.
  #
  #   begin
  #     chat.ask "What's due today?"
  #   rescue RubyLLM::BadRequestError => e
  #     Rails.logger.error("#{e.message}\n#{e.request_shape}")
  #     Rails.error.report(e, context: { request_shape: e.request_shape.to_h })
  #     raise
  #   end
  #
  # A shape holds no text, tool arguments, tool results, signatures, URLs,
  # file data, or setting values beyond thinking settings, so you can log it
  # and send it to an error tracker. A long conversation keeps its first 10
  # and last 50 turns.
  class RequestShape
    include Support::Inspectable

    # The provider's slug, such as <tt>"gemini"</tt>.
    attr_reader :provider

    # The id of the model the request went to.
    attr_reader :model

    # Which model call of the current turn the request makes, counting from
    # 1, so +3+ follows two tool rounds. Returns +nil+ when the request holds
    # no user turn to count from.
    attr_reader :step

    # The names of the payload's top-level fields, without their values.
    attr_reader :payload_keys

    # The thinking settings the request sends, such as an effort or a budget,
    # as a Hash of the provider's setting names and values.
    attr_reader :thinking_settings

    # The Part objects of the instructions the request sends apart from its
    # turns, or an empty Array when the provider takes instructions as a turn.
    attr_reader :instructions

    # The Turn objects of the conversation, in the order the request sends
    # them. A long conversation keeps its first 10 and last 50 turns.
    attr_reader :turns

    # The number of turns the request sends, including omitted ones.
    attr_reader :turn_count

    # The number of turns left out of #turns.
    attr_reader :omitted_turns

    # The names of the tools the request offers, in order. Provider tools
    # keep the name their provider's API gives them.
    attr_reader :tool_names

    # The ToolRound objects of the turns kept, one for each model turn that
    # called tools.
    attr_reader :tool_rounds

    # The Problem objects RubyLLM finds in the request, across every turn.
    attr_reader :problems

    # Creates a shape. Protocols build shapes in
    # Protocol#parse_request_shape; every attribute but +turns+ is optional.
    def initialize(turns:, provider: nil, model: nil, step: nil, payload_keys: [], thinking_settings: {},
                   instructions: [], turn_count: nil, omitted_turns: 0, tool_names: [], tool_rounds: [], problems: [])
      @turns = turns
      @provider = provider
      @model = model
      @step = step
      @payload_keys = payload_keys
      @thinking_settings = thinking_settings
      @instructions = instructions
      @turn_count = turn_count || turns.size
      @omitted_turns = omitted_turns
      @tool_names = tool_names
      @tool_rounds = tool_rounds
      @problems = problems
    end

    # Returns the shape as text, one turn per line:
    #
    #   gemini, gemini-2.5-flash, model call 1 of the turn
    #   payload keys: contents, generationConfig, tools
    #   thinking: includeThoughts true, thinkingBudget -1
    #   #0 user: text (17 chars)
    #   #1 model: call find_tasks (args 40 chars), signed
    #   #2 user: result find_tasks (6859 chars)
    #   #3 model: thinking (no text), signed, text (1075 chars)
    #   #4 user: text (31 chars)
    #   tools: find_tasks
    #   tool round at #1: 1 call, 1 result, paired
    #   problem at #3, part 0: thinking part carries no data
    #
    def to_s
      [summary_line, list_line('payload keys', payload_keys), settings_line, list_line('instructions', instructions),
       *turn_lines, list_line('tools', tool_names), *tool_rounds.map(&:to_s), *problem_lines].compact.join("\n")
    end

    # Returns the shape as a Hash with the same keys every time, for
    # structured logs and error trackers.
    def to_h
      {
        provider: provider, model: model, step: step, payload_keys: payload_keys,
        thinking_settings: thinking_settings, instructions: instructions.map(&:to_h),
        turn_count: turn_count, omitted_turns: omitted_turns, turns: turns.map(&:to_h),
        tool_names: tool_names, tool_rounds: tool_rounds.map(&:to_h), problems: problems.map(&:to_h)
      }
    end

    def inspect_attributes # :nodoc:
      { provider: provider, model: model, turns: turn_count, problems: problems.size }
    end

    private

    def summary_line
      line = [provider, model, step_description].compact.join(', ')
      line unless line.empty?
    end

    def step_description
      return unless step

      rounds = step - 1
      description = "model call #{step} of the turn"
      return description unless rounds.positive?

      "#{description}, after #{rounds} tool #{rounds == 1 ? 'round' : 'rounds'}"
    end

    def list_line(label, items)
      "#{label}: #{items.join(', ')}" if items.any?
    end

    def settings_line
      "thinking: #{thinking_settings.map { |name, value| "#{name} #{value}" }.join(', ')}" if thinking_settings.any?
    end

    def turn_lines
      turns.each_cons(2).flat_map { |turn, following| [turn.to_s, *gap_line(turn, following)] }
           .push(*turns.last&.to_s)
    end

    def gap_line(turn, following)
      gap = following.index - turn.index - 1
      "(#{gap} #{gap == 1 ? 'turn' : 'turns'} omitted)" if gap.positive?
    end

    def problem_lines
      problems.any? ? problems.map(&:to_s) : ['no problems found']
    end
  end
end
