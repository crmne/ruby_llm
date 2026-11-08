# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # The questions a persisted chat waits on, kept on its tool call rows:
    # approvals, and the questions tools and MCP servers ask (see
    # RubyLLM::Question). Any process reads them from the database, without
    # building the chat, and records answers on those rows under a row
    # lock, so a web request can answer what a job asked and another job
    # can carry the call on. ChatMethods includes it.
    #
    #   chat.pending_questions.each { |question| render "questions/question", question: }
    #   chat.answer(params[:question_id], params[:answer])
    #   ChatResponseJob.perform_later(chat.id)
    #
    module ChatQuestions
      # Returns the questions the chat waits on a person to answer, as
      # RubyLLM::Question objects in the order the model made their calls:
      # approvals, and the questions tools and MCP servers ask, as
      # RubyLLM::Chat#pending_questions describes. It reads the database
      # only, so it never builds the chat's tools or connects to its MCP
      # servers, and it lists what any process recorded. Each question
      # records its answer on this chat.
      #
      # Whether a call requires approval is decided when it is saved, by the
      # process that received it, so a call whose tool decides with a
      # Tool.requires_approval block stays listed until the chat runs again.
      def pending_questions
        approvals = persisted_pending_approvals.to_a
        rows = RubyLLM::ActiveRecord::ToolCall.uncached { chat_tool_calls.where(result_id: nil).order(:created_at, :id).to_a }
        rows.flat_map do |row|
          tool_call = row.to_llm
          next [RubyLLM::Question.approval(tool_call, chat: self)] if approvals.include?(row)

          Array(row.mcp_state&.[]('requests')).filter_map do |data|
            RubyLLM::Question.from_h(data, tool_call:, chat: self) unless data['response']
          end
        end
      end

      # Answers +question+, a RubyLLM::Question from #pending_questions or
      # its id, on its tool call record, so the next +complete+ in any
      # process carries the call on, as RubyLLM::Chat#answer describes.
      # Answering an approval approves it, as +approve+ does, unless another
      # decision came first, in this process or another. Takes the
      # ActionController::Parameters a form sends for several fields, and
      # keeps only those the question asks for. Returns +self+.
      #
      #   chat.answer(params[:question_id], params[:answer])
      #
      # Raises ArgumentError for a question the chat never asked, and for an
      # answer the question can't take.
      def answer(question, value = nil, **values)
        pending = persisted_pending_question(question)
        response = pending&.response_to(value, values)
        return self unless pending && settle_persisted_question(pending, response)

        question.respond(response) if question.is_a?(RubyLLM::Question)
        self
      end

      # Declines +question+, a RubyLLM::Question from #pending_questions,
      # its id, or the call of an approval, on its tool call record, as
      # RubyLLM::Chat#decline describes, unless another decision came
      # first. The +note+ persists with it, so whichever process carries
      # the call on gives the model the same note. A call saved waiting for
      # approval before 2.2 is declined by its id, as +approve+ approves
      # it, though #pending_questions leaves it out. Returns +self+.
      #
      #   chat.decline(params[:question_id], params[:note])
      #
      # Raises ArgumentError for a question the chat never asked, and
      # RubyLLM::ToolCallRunningError for an approval still pending whose
      # call is already running.
      def decline(question, note = nil)
        pending = persisted_pending_question(question) || unmarked_approval(question)
        response = RubyLLM::Question.declined(note)
        return self unless pending && settle_persisted_question(pending, response)

        question.respond(response) if question.is_a?(RubyLLM::Question)
        self
      end

      def settle_persisted_input(tool_call) # :nodoc:
        transaction do
          # Writing first takes the row's lock on every database, SQLite
          # included, so the state read next is the latest.
          scope = chat_tool_calls.where(tool_call_id: tool_call.id, result_id: nil)
          next unless scope.update_all(updated_at: Time.current) == 1

          locked = RubyLLM::ActiveRecord::ToolCall.uncached { scope.lock.take }
          next if locked.mcp_state.nil?

          settled = yield(locked.mcp_state)
          next if settled == locked.mcp_state

          forget_stale_cancellation
          locked.update!(mcp_state: settled)
        end
      end

      # Returns the note +tool_call+ was declined with while it waits for
      # its refusal. It is kept in +mcp_result+, which the call's result
      # replaces, and never in +mcp_state+, where a note would look like
      # a question the call waits on.
      def persisted_decline_note(tool_call) # :nodoc:
        record = RubyLLM::ActiveRecord::ToolCall.uncached { find_tool_call(tool_call.id) }
        record.mcp_result&.[]('note') if record&.has_attribute?(:mcp_result) && record.result_id.nil?
      end

      def record_persisted_decline_note(tool_call, note) # :nodoc:
        return unless RubyLLM::ActiveRecord::ToolCall.column_names.include?('mcp_result')

        chat_tool_calls.where(tool_call_id: tool_call.id, result_id: nil)
                       .update_all(mcp_result: note && { 'note' => note }, updated_at: Time.current)
      end

      private

      def persisted_pending_question(question)
        id = persisted_question_id(question)
        pending_questions.find { |pending| pending.id == id } ||
          (persisted_question?(id) ? nil : raise(ArgumentError, "Unknown question: #{id.inspect}"))
      end

      def persisted_question_id(question)
        id = question.respond_to?(:tool_call_id) ? question.tool_call_id : question
        (id.respond_to?(:id) ? id.id : id).to_s
      end

      # A call saved before 2.2 waits for approval with no +pending+ mark,
      # so #pending_questions can't list it, but it can be declined as
      # +approve+ approves it.
      def unmarked_approval(question)
        return if question.is_a?(RubyLLM::Question) && !question.approval?

        record = RubyLLM::ActiveRecord::ToolCall.uncached { find_tool_call(persisted_question_id(question)) }
        return unless record && record.approval.nil? && record.result_id.nil?

        RubyLLM::Question.approval(record.to_llm, chat: self)
      end

      def persisted_question?(id)
        RubyLLM::ActiveRecord::ToolCall.uncached do
          [id, id.rpartition('/').first].any? { |tool_call_id| find_tool_call(tool_call_id) }
        end
      end

      def record_persisted_answer(question, response)
        settle_persisted_input(question.tool_call) { |input| question.answered_input(input, response) }
      end

      # Records +response+ to +question+ and returns whether it did. An
      # approval is approved or denied only while it still waits, so of
      # two people deciding at once, in any processes, the first one's
      # decision stands.
      def settle_persisted_question(question, response)
        unless question.approval?
          record_persisted_answer(question, response)
          return true
        end

        waiting = RubyLLM::ActiveRecord::ToolCall.where(id: tool_call_record(question.tool_call.id).id,
                                                        approval: ['pending', nil], result_id: nil)
        transaction do
          # Writing first takes the row's lock on every database, SQLite
          # included, so a decision made at the same time waits for this
          # one and then finds the call decided.
          next false unless waiting.update_all(updated_at: Time.current) == 1

          response == RubyLLM::Question::ACCEPTED ? approve(question) : refuse(question, response['note'])
          true
        end
      end

      def refuse(question, note)
        record_tool_call_decision(question.tool_call, 'denied')
        record_persisted_decline_note(question.tool_call, note) if note
      end
    end
  end
end
