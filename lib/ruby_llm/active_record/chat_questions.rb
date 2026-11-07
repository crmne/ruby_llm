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

      # Declines +question+, a RubyLLM::Question from #pending_questions or
      # its id, on its tool call record, as RubyLLM::Chat#decline describes.
      # Declining an approval denies it, as +deny+ does, unless another
      # decision came first. Returns +self+.
      #
      # Raises ArgumentError for a question the chat never asked.
      def decline(question)
        pending = persisted_pending_question(question)
        return self unless pending && settle_persisted_question(pending, RubyLLM::Question::DECLINED)

        question.respond(RubyLLM::Question::DECLINED) if question.is_a?(RubyLLM::Question)
        self
      end

      # Returns the questions among #pending_questions that are not
      # approvals.
      def pending_inputs
        pending_questions.reject(&:approval?)
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

      private

      def persisted_pending_question(question)
        id = question.respond_to?(:tool_call_id) ? question.tool_call_id : question
        id = (id.respond_to?(:id) ? id.id : id).to_s
        pending_questions.find { |pending| pending.id == id } ||
          (persisted_question?(id) ? nil : raise(ArgumentError, "Unknown question: #{id.inspect}"))
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
                                                        approval: 'pending', result_id: nil)
        transaction do
          # Writing first takes the row's lock on every database, SQLite
          # included, so a decision made at the same time waits for this
          # one and then finds the call decided.
          next false unless waiting.update_all(updated_at: Time.current) == 1

          response == RubyLLM::Question::ACCEPTED ? approve(question) : deny(question)
          true
        end
      end
    end
  end
end
