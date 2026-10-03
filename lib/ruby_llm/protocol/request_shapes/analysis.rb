# frozen_string_literal: true

module RubyLLM
  class Protocol
    module RequestShapes
      # Finds what a provider would refuse in the turns a protocol read: parts
      # with no data, empty turns, tool rounds whose calls and results do not
      # pair up, and results that answer no call, plus the rules a protocol
      # opts into. +pairing+ is how the provider matches results to calls:
      # +:id+, or +:position+, which compares tool names in order. The rules
      # are +:signed_steps+, where the first call of each step in the current
      # turn needs a signature; +:signed_thinking+, where every thinking part
      # does; and +:alternating_roles+, where user and model turns alternate,
      # starting with the user.
      class Analysis # :nodoc: all
        KEPT_FIRST_TURNS = 10
        KEPT_LAST_TURNS = 50

        Round = Struct.new(:turn, :calls, :results)

        def initialize(turns, pairing:, rules:)
          @turns = turns
          @pairing = pairing
          @rules = rules
          name_results
        end

        def kept_turns
          return @turns if @turns.size <= KEPT_FIRST_TURNS + KEPT_LAST_TURNS

          @turns.first(KEPT_FIRST_TURNS) + @turns.last(KEPT_LAST_TURNS)
        end

        # The request is the model call after every round of the current
        # turn, which starts after the last user turn.
        def step
          rounds.count { |round| round.turn.index > last_user_turn.index } + 1 if last_user_turn
        end

        def tool_rounds
          kept = kept_turns.to_set(&:index)
          rounds.select { |round| kept.include?(round.turn.index) }.map do |round|
            RequestShape::ToolRound.new(turn: round.turn.index, calls: round.calls.size,
                                        results: round.results.size, paired: paired?(round))
          end
        end

        def problems
          found = [*parts_without_data, *empty_turns, *unpaired_rounds, *unmatched_results, *unsigned_calls,
                   *unsigned_thinking, *roles_out_of_order]
          found.each_with_index.sort_by { |problem, order| [problem.turn, problem.part || -1, order] }.map(&:first)
        end

        private

        def located_parts(turns = @turns)
          turns.flat_map { |turn| turn.parts.each_with_index.map { |part, position| [turn, position, part] } }
        end

        def last_user_turn
          @turns.reverse.find { |turn| turn.speaker == :user }
        end

        def name_results
          return unless @pairing == :id

          names = {}
          located_parts.each do |_, _, part|
            names[part.call_id] = part.name if part.call? && part.call_id
            part.name ||= names[part.result_id] if part.result?
          end
        end

        # Consecutive model turns make one round, answered by the results in
        # the turns that follow them up to the next model turn.
        def rounds
          @rounds ||= runs(@turns).push([]).each_cons(2).filter_map { |run, answers| round(run, answers) }
        end

        def round(run, answers)
          calls = run.flat_map(&:parts).select(&:call?)
          Round.new(run.first, calls, answers.flat_map(&:parts).select(&:result?)) if run.first.model? && calls.any?
        end

        def runs(turns)
          turns.slice_when { |turn, following| turn.model? != following.model? }.to_a
        end

        def paired?(round)
          calls = round.calls
          results = round.results
          return false unless calls.size == results.size
          return calls.map(&:name) == results.map(&:name) unless @pairing == :id && (calls + results).all? { ids?(_1) }

          calls.map(&:call_id).tally == results.map(&:result_id).tally
        end

        def ids?(part)
          part.call? ? part.call_id : part.result_id
        end

        def parts_without_data
          located_parts.filter_map do |turn, position, part|
            next unless part.without_data

            noun = part.kind == :other ? 'part' : "#{part.kind} part"
            problem(:part_without_data, "#{noun} carries no data", turn:, part: position)
          end
        end

        def empty_turns
          @turns.select { |turn| turn.parts.empty? }.map { |turn| problem(:empty_turn, 'turn has no parts', turn:) }
        end

        def unpaired_rounds
          rounds.reject { |round| paired?(round) }.map do |round|
            calls = counted(round.calls.size, 'call')
            results = counted(round.results.size, 'result')
            message = if round.calls.size == round.results.size
                        "#{calls} and #{results} that do not pair up"
                      else
                        "#{calls} but #{results}"
                      end
            problem(:unpaired_round, message, turn: round.turn)
          end
        end

        # The one place a shape shows an id: a result naming a call the
        # request never made can only be traced by the id it names.
        def unmatched_results
          return [] unless @pairing == :id

          called = Set.new
          located_parts.filter_map do |turn, position, part|
            called << part.call_id if part.call? && part.call_id
            next unless part.result? && !called.include?(part.result_id)

            message = 'result answers no call in the request'
            problem(:unmatched_result, message, turn:, part: position, call_id: part.result_id)
          end
        end

        def unsigned_calls
          return [] unless @rules.include?(:signed_steps)

          start = last_user_turn ? @turns.index(last_user_turn) + 1 : 0
          runs(@turns.drop(start)).select { |run| run.first.model? }.filter_map do |run|
            turn, position, call = located_parts(run).find { |_, _, part| part.call? }
            next if call.nil? || call.signed

            message = 'first call of a step in the current turn has no signature'
            problem(:unsigned_call, message, turn:, part: position)
          end
        end

        def unsigned_thinking
          return [] unless @rules.include?(:signed_thinking)

          located_parts.filter_map do |turn, position, part|
            next unless part.kind == :thinking && !part.signed

            problem(:unsigned_thinking, 'thinking part has no signature', turn:, part: position)
          end
        end

        def roles_out_of_order
          return [] unless @rules.include?(:alternating_roles)

          turns = @turns.reject { |turn| turn.speaker == :system }
          problems = turns.each_cons(2).filter_map do |turn, following|
            next unless turn.model? == following.model?

            problem(:role_order, "follows another #{following.model? ? 'model' : 'user'} turn", turn: following)
          end
          first = turns.first
          problems.unshift(problem(:role_order, 'conversation starts with a model turn', turn: first)) if first&.model?
          problems
        end

        def problem(kind, message, turn:, part: nil, call_id: nil)
          RequestShape::Problem.new(kind:, message:, turn: turn.index, part:, call_id:)
        end

        def counted(count, noun)
          "#{count} #{noun}#{'s' unless count == 1}"
        end
      end
    end
  end
end
