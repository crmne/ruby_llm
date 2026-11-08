# frozen_string_literal: true

require 'json'

module RubyLLM
  # A Chat is a conversation with an AI model. It holds the messages
  # exchanged so far, the tools the model may call, and the settings applied
  # to each request. RubyLLM.chat is the usual way to create one.
  #
  #   chat = RubyLLM.chat
  #   chat.ask "What's the best way to learn Ruby?"
  #
  # Configuration methods return +self+, so calls chain:
  #
  #   chat = RubyLLM.chat(model: 'claude-sonnet-5')
  #   chat.with_instructions("Be terse.").with_tools(Weather)
  #
  # #ask runs the conversation loop, executing tools until the model answers
  # or a call waits on a person. #ask_later, #generate, #run_tools, and
  # #step expose individual operations. Answer what a paused call asks,
  # an approval included (see #pending_questions), then #complete carries
  # it on. #queue adds a message from anywhere, even while the loop runs,
  # and the loop takes it between two moves.
  #
  # Read the conversation through #messages.
  class Chat # rubocop:disable Metrics/ClassLength
    include Support::Inspectable
    include Support::DeprecatedEnumerable
    include ToolSearch
    include ToolSequences
    prepend AgentRun
    prepend Rescuable
    prepend Ownership

    # The provider-neutral options #with_compaction accepts.
    COMPACTION_OPTIONS = %i[at instructions pause_after].freeze
    THINKING_OPTIONS = %i[effort budget display].freeze
    PAUSED = Object.new.freeze
    TOOL_CHOICE_MODES = %i[auto none required].freeze
    AGENT_RUN_KEY = :ruby_llm_agent_run
    COPIED_STATE = %i[
      @usage_entries @tools @tool_deferrals @mcp @mcp_deferrals @tool_prefs @headers @attachment_replacements
      @tool_call_state
    ].freeze
    UNFINISHED_TOOL_RESULT = { error: 'The tool call did not finish.' }.to_json.freeze
    # Not a RubyLLM::Error, which a record takes for a failed request and
    # answers by removing the round.
    class StalledToolRound < StandardError; end # :nodoc:
    private_constant :THINKING_OPTIONS, :PAUSED, :TOOL_CHOICE_MODES, :AGENT_RUN_KEY, :COPIED_STATE,
                     :UNFINISHED_TOOL_RESULT, :StalledToolRound

    # The Model the chat sends requests to.
    attr_reader :model

    # Returns the id of the Model the chat sends requests to.
    #
    #   chat.model_id # => "gpt-6-luna"
    #
    def model_id
      model.id
    end

    # The Provider instance handling requests for the current model.
    attr_reader :provider

    # The Message objects exchanged so far, including system instructions.
    attr_reader :messages

    # The MCP servers connected with #with_mcp, readable by name:
    # <tt>chat.mcp.linear</tt>.
    attr_reader :mcp

    # The provider tools enabled with #with_provider_tools, as an array of
    # normalized entry Hashes.
    attr_reader :provider_tools

    # Extra request options set with #with_provider_options, expressed in
    # the provider's request vocabulary.
    attr_reader :provider_options

    # Extra HTTP headers set with #with_headers.
    attr_reader :headers

    # The sampling temperature set with #with_temperature, or +nil+ to let
    # the model use its default.
    attr_reader :temperature

    # The output cap set with #with_max_output_tokens, or +nil+.
    attr_reader :max_output_tokens

    # The normalized structured output schema set with #with_schema, or +nil+.
    attr_reader :schema

    # The tool concurrency mode, or +nil+ when tools run sequentially.
    attr_reader :concurrency

    # The prompt caching options set with #with_caching, +false+ when
    # explicitly disabled, or +nil+ when not configured.
    attr_reader :caching

    # The context compaction options set with #with_compaction, +false+ when
    # explicitly disabled, or +nil+ when not configured.
    attr_reader :compaction

    # The shares of the context window set with #with_context_budget, or
    # else Configuration#context_budget. Returns +nil+ when not configured.
    attr_reader :context_budget

    # The opaque per-user identifier set with #with_end_user, or
    # +nil+.
    attr_reader :end_user

    # Whoever the chat's usage is attributed to: the owner set with
    # #with_owner, or else, for a persisted chat, the record its
    # +acts_as_chat+ declaration names with +owner:+. Returns +nil+ when
    # neither is set.
    def owner
      @owner || @run.owner
    end

    # The Fallback models tried in order when generation fails.
    attr_reader :fallbacks

    # Whether #with_citations asked the provider for citations.
    attr_reader :citations

    # The code execution options set with #with_code_execution, +false+
    # when explicitly disabled, or +nil+ when not configured.
    attr_reader :code_execution

    # The Skill objects given with #with_skills, empty without skills.
    attr_reader :skills

    # The Context this chat sends requests through, or +nil+ for the global
    # configuration.
    attr_reader :context

    attr_reader :tool_prefs, :fallback_errors, :usage_entries # :nodoc:

    # Returns the +choice+, +calls+, and +concurrency+ set with
    # #with_tool_options, with +nil+ for anything left at the default.
    def tool_options
      { choice: tool_prefs[:choice], calls: tool_prefs[:calls], concurrency: concurrency }
    end

    # Creates a chat with +model:+, or with the configured default model
    # when +model:+ is +nil+. Most code calls RubyLLM.chat instead.
    #
    # A model is identified by its name, an optional +provider:+, and an
    # optional +protocol:+. Pass +provider:+ to disambiguate models
    # available from several providers, and +protocol:+ to override the wire
    # protocol the provider would otherwise pick for the model. With
    # <tt>assume_model_exists: true</tt> the registry lookup is skipped,
    # which requires +provider:+. Pass a Context as +context:+ to use its
    # configuration instead of the global one.
    def initialize(model: nil, provider: nil, protocol: nil, assume_model_exists: false, context: nil)
      if assume_model_exists && !provider
        raise ArgumentError, 'Provider must be specified if assume_model_exists is true'
      end

      @context = context
      @config = context&.config || RubyLLM.config
      with_model(model, provider: provider, protocol: protocol, assume_model_exists: assume_model_exists)
      @temperature = nil
      @max_output_tokens = nil
      @messages = []
      @usage_entries = []
      @tools = {}
      @mcp = MCP::Collection.new
      @tool_deferrals = {}
      @mcp_deferrals = {}
      @provider_tools = []
      @tool_prefs = { choice: nil, calls: nil }
      apply_tool_concurrency(nil)
      @provider_options = {}
      @headers = {}
      @schema = nil
      @thinking = nil
      @citations = false
      @caching = nil
      @compaction = nil
      @context_budget = @config.context_budget
      @code_execution = nil
      @code_execution_tool = nil
      @skills = []
      @skill_loader = build_skill_loader
      @file_references = nil
      @file_tools = []
      @end_user = nil
      @fallbacks = []
      @fallback_errors = Fallback::DEFAULT_ERRORS
      @drop_unsupported = false
      @answering_fallback = false
      @callbacks = Hash.new { |callbacks, name| callbacks[name] = [] }
      @attachment_replacements = {}.compare_by_identity
      @cancelled = false
      @run = Run.new
      @tool_call_state = ToolCallState.new
      @message_queue = build_message_queue
    end

    ##
    # :method: dup
    # :call-seq: dup()
    #
    # Returns an independent copy of the chat, for branching a conversation.
    # The copy starts with the same messages, tools, options, and callbacks,
    # and changes to either chat leave the other alone. #clone does the
    # same.
    #
    #   branch = chat.dup
    #   branch.ask "What if we used Postgres instead?"
    #   chat.messages.length # unchanged
    #
    # Tool instances, connected MCP servers, and the provider connection
    # are shared. A cancellation or a run in progress stays with the
    # original. The copy starts with the same queued messages in a queue
    # of its own.

    def initialize_copy(source) # :nodoc:
      super
      @messages = @messages.map { |message| coerce_message(message.dup) }
      COPIED_STATE.each { |name| instance_variable_set(name, instance_variable_get(name).dup) }
      @provider_tools = Support::Utils.deep_dup(@provider_tools)
      @provider_options = Support::Utils.deep_dup(@provider_options)
      @callbacks = @callbacks.dup.transform_values!(&:dup)
      @skill_loader = build_skill_loader
      @tool_search_tool = nil
      with_code_execution(**@code_execution) if @code_execution
      if @file_references
        with_file_store(file_store, inline_limit: @file_references.inline_limit, tools: @file_references.tools)
      end
      @message_queue = build_message_queue(@message_queue.to_a) if @message_queue.is_a?(MessageQueue)
      @cancelled = false
    end

    # Adds +message+ as a user message and runs the conversation loop,
    # executing tools until the model answers or a call needs approval.
    # Returns the latest assistant Message; check #waiting? before
    # treating it as a final answer. Attach files with +with:+. An
    # MCP::Prompt adds its messages instead, and takes no attachments.
    # Messages still in the queue
    # (see #queue) join the conversation first, in order.
    # A given block receives streamed Chunk objects as they arrive.
    #
    # String attachments read local paths or fetch URLs. Only pass trusted,
    # authorized sources; validate user uploads before calling this method.
    # See Attachment.new.
    #
    #   chat.ask "What's the best way to learn Ruby?"
    #   chat.ask "What's in this image?", with: "ruby_conf.jpg"
    #   chat.ask "Analyze these files", with: ["diagram.png", "report.pdf"]
    #   chat.ask("Tell me a story") { |chunk| print chunk.content }
    #   chat.ask github.prompt(:code_review, code: diff)
    #
    def ask(message = nil, with: nil, &)
      ask_later(message, with: with)
      complete(&)
    end

    alias say ask

    # Stages +message+ as a user message without requesting a completion,
    # leaving the chat ready for #complete, a single #step, or a
    # provider-side batch via RubyLLM.batch. Accepts attachments with
    # +with:+ like #ask. Returns +self+.
    #
    #   chats = tickets.map { |t| RubyLLM.chat.ask_later(t.body) }
    #   RubyLLM.batch(chats)
    #
    # Every message still in the queue (see #queue) joins the conversation
    # first, in order, whether it steers or not.
    #
    # Raises PendingToolCallsError while the last response has unanswered
    # tool calls: finish the round first, recording #approve or #decline
    # decisions for calls that require approval.
    def ask_later(message = nil, with: nil)
      raise_if_pending_tool_calls!
      raise_if_prompt_attachments!(message, with)
      take_queued_messages
      if message.is_a?(MCP::Prompt)
        message.messages.each { |prompt_message| add_message(prompt_message) }
      else
        add_message role: :user, content: message, attachments: with
      end
      self
    end

    # Requests one completion from the model, appends the response to the
    # conversation, and returns it as a Message. Honors the fallbacks
    # configured with #with_fallbacks. A given block receives streamed
    # Chunk objects. Tool calls in the response are not executed; that is
    # #run_tools.
    def generate(&)
      raise_if_cancelled!

      return generate_once(&) if fallbacks.empty? && !@drop_unsupported

      with_model_restored { generate_with_fallbacks(&) }
    rescue CancelledError
      @cancelled = false
      raise
    end

    # Executes the tool calls pending in the latest response and appends
    # their result messages, without asking the model to respond. Tool
    # calls that already have results are skipped, so a chat reloaded
    # mid-round resumes with only the remaining tools. Calls whose tool
    # was declared with Tool.requires_approval only execute once #approve
    # records a decision; denied calls receive a structured denial result,
    # and undecided calls stay pending. Does nothing when no tool calls
    # are pending. Calls paused on a Task resume once. The chat
    # is then ready for the next #generate, or the next batch round.
    # Returns +self+.
    def run_tools
      raise_if_cancelled!

      message = pending_tool_response
      execute_pending_tool_calls(message) if message
      raise_if_cancelled!
      self
    rescue CancelledError
      stop_tool_round
      raise
    end

    # Advances the conversation by one move: runs the pending tool calls
    # if any are unanswered, otherwise generates the next response.
    # Returns the Message that move produced, and +nil+ once there is
    # nothing left to do or the chat is #waiting?.
    #
    # Unless tool calls are pending, every message in the queue (see
    # #queue) joins the conversation before the model is asked, whether it
    # steers or not.
    def step(&)
      advance(steering_only: false, &)
    end

    # Runs the conversation loop until #complete? or #waiting? is +true+.
    # Returns the last conversation Message, or +nil+ for an empty chat.
    # While the chat is #waiting?, returns the assistant Message that holds
    # the pending tool calls, even after other tools in the round have run.
    # Used after #ask_later; #ask calls #complete for you.
    #
    # When a pending tool call requires approval and no decision has been
    # recorded, or waits on input for an MCP server, the loop pauses.
    # Record #approve, #answer, or #decline decisions, then call
    # #complete again to continue. A tool call that returns a Task pauses
    # the loop too, and each #complete resumes it once with Tool#resume,
    # without waiting, and continues once it has a result. For an MCP tool,
    # that checks on its MCP::Task.
    #
    # A turn starts once a question is in place. When the model has
    # answered the last one, every message in the queue joins first, in
    # order, and starts the next turn. Within a turn, only messages that
    # steer join, after each round of tool results and after the answer,
    # so the turn goes on until the model has answered them. Messages
    # queued with <tt>steer: false</tt> wait for the turn to end. A
    # #complete on an unanswered chat, such as one after #ask_later, a
    # retry, or a pause for an approval, continues that turn: only
    # messages that steer join. See #queue.
    def complete(&)
      resuming = !answered?
      run_tools if pending_tasks.any?
      continue_turn(steering_only: resuming, &)
    end

    # Runs the loop like #complete. With <tt>steering_only: true</tt> the
    # loop goes on with the turn that is running, so messages queued with
    # <tt>steer: false</tt> stay queued.
    def continue_turn(steering_only: true, &) # :nodoc:
      until settled?(steering_only) || waiting?
        boundary = !pending_tool_response
        move = advance(steering_only:, &)
        break if placeholder?(move)

        stalled = stalled_round?(stalled, generated: boundary, move:)
        steering_only ||= boundary
      end
      @cancelled = false
      pending_tool_response || halted_result || last_non_system_message || messages.last
    end

    # Returns whether the chat has no pending response or tool execution:
    # nothing is staged, the model answered without requesting tools, or a
    # tool ended the turn with Tool#halt once its round finished,
    # and no queued message steers the turn. Messages queued with
    # <tt>steer: false</tt> don't count, so the chat is complete while
    # they wait for the next #complete.
    def complete?
      settled?(true)
    end

    # Adds +message+ to the queue: a user message that waits outside the
    # conversation until the loop takes it. Call it at any time, from any
    # thread, even while #complete runs in another one. Attach files with
    # +with:+, as with #ask. Returns the QueuedMessage.
    #
    #   chat.queue "Use the EU file instead"
    #   chat.queue "Then email it to me", steer: false
    #   chat.queue "Check this one too", with: "q3.pdf", sender: current_user
    #
    # A message that steers, the default, joins the turn that is running:
    # after the next round of tool results, or once the model finishes its
    # answer, which then goes on to answer it too. Pass <tt>steer: false</tt>
    # to wait for the turn to end instead: #complete returns, the chat is
    # #complete?, and the next #ask, #ask_later, or #complete on the
    # answered chat takes the message, as does a #step with no tool calls
    # pending. Steering messages can join before waiting ones queued
    # earlier. Messages that join together become separate user messages,
    # oldest first.
    #
    # Nothing is taken while the chat is #waiting?, and #cancel leaves the
    # queue as it is. Queueing never runs the loop: when nothing is
    # running, call #complete. +sender+, whoever queued the message, is
    # stored with it and handed back without RubyLLM interpreting it.
    def queue(message = nil, with: nil, steer: true, sender: nil)
      @message_queue.push(content: message, attachments: with, steer:, sender:)
    end

    # Returns the messages waiting in the queue, as QueuedMessage objects,
    # oldest first.
    def queued_messages
      @message_queue.to_a
    end

    # Takes +queued+, a QueuedMessage or its id, out of the queue before the
    # loop takes it. Returns +true+, or +false+ when it is no longer queued:
    # the loop took it into the conversation, or it was withdrawn already.
    # QueuedMessage#withdraw does the same from the message.
    #
    #   chat.withdraw(queued) # => true
    #
    def withdraw(queued)
      !@message_queue.delete(queued).nil?
    end

    # Adds every queued message to the conversation, without asking the
    # model, and returns the user Message objects they became, oldest
    # first. Each message joins through #around_join and runs
    # #after_message, whether it steers or not.
    #
    #   chat.queue "Use the EU file"
    #   chat.queue "Then email it to me", steer: false
    #   chat.join_queued_messages.map(&:content) # => ["Use the EU file", "Then email it to me"]
    #
    # Raises PendingToolCallsError while the last response has unanswered
    # tool calls, as #ask_later does.
    def join_queued_messages
      raise_if_pending_tool_calls!
      take_queued_messages
    end

    # Adds every queued message to the conversation, or with
    # <tt>steering_only: true</tt> only those that steer, and runs
    # #after_message for each one that joined. Returns the joined messages.
    def take_queued_messages(steering_only: false) # :nodoc:
      joined = []
      @message_queue.take(steering_only:) do |message|
        next unless message

        joined << message
        run_callbacks(:after_message, messages.last)
      end
      joined
    end

    # Runs the #around_join callbacks for +queued+, outermost first, around
    # the given block, which adds the message with the attributes the
    # callbacks pass to +join+. Returns the message, or +nil+ when a
    # callback withdrew it. Takes the message back out of the conversation
    # when a callback raises.
    def run_around_join(queued, &add) # :nodoc:
      joined = nil
      size = messages.length
      innermost = ->(**attributes) { joined ||= add.call(**attributes) }
      chain = @callbacks[:around_join].reverse.reduce(innermost) do |inner, callback|
        lambda do |**outer|
          callback.call(queued, lambda { |**attributes|
            inner.call(**outer, **attributes)
            joined
          })
        end
      end
      chain.call
      joined
    rescue StandardError
      messages.slice!(size..)
      raise
    end

    # Records approval for +tool_call+, the approval Question from
    # #pending_questions, its ToolCall, or its id, so the next #complete or
    # #run_tools executes a local tool or records permission for the
    # provider to execute a remote tool on the next request. Returns
    # +self+. Question#approve does the same.
    #
    #   chat.approve(tool_call)
    #   chat.complete
    #
    # With <tt>remember: true</tt>, later calls to the same tool run without
    # asking for the rest of the chat.
    #
    #   chat.approve(tool_call, remember: true)
    #
    # Approving a call that already has a result remembers nothing.
    #
    # A +run_code+ call that asks for another sandbox is approved one call
    # at a time: passing <tt>remember: true</tt> for it raises
    # ArgumentError, and the approval never applies to another call.
    # Raises ArgumentError for a Question that is not an approval.
    def approve(tool_call, remember: false)
      tool_call = Question.decided_call(tool_call, 'answer')
      name = remembered_tool_identity(tool_call) if remember
      record_tool_call_decision(tool_call, true)
      @tool_call_state.remember(name) if name && !tool_call_answered?(tool_call)
      self
    end

    # Returns whether the conversation can't continue until something
    # outside it happens: every remaining pending tool call waits on an
    # answer to a question, a Task, or a run in another process.
    # #complete stops here, and #pending_questions and #pending_tasks tell
    # what it waits on. Stop a loop you drive with #step here too:
    #
    #   chat.step until chat.complete? || chat.waiting?
    #
    def waiting?
      response = pending_tool_response
      return false unless response

      pending = pending_tool_calls(response)
      pending.any? && pending.all? do |tool_call|
        approval_pending?(tool_call) || paused?(tool_call) ||
          running_elsewhere?(tool_call) || sequence_blocked?(tool_call) || exclusive_blocked?(tool_call)
      end
    end

    # Returns the questions the conversation waits on a person to answer,
    # as Question objects, in the order the model made their calls: the
    # approvals of tools declared with Tool.requires_approval, which ask
    # before the tool runs, and the questions tools ask with Tool#ask and
    # MCP servers ask while they work. Empty when nothing waits on a person.
    #
    #   chat.ask "Book me a flight to Lisbon"
    #   question = chat.pending_questions.first
    #   question.message         # => "Window or aisle?", or nil for an approval
    #   question.answer "window" # as the person chose; approve or decline an approval
    #   chat.complete
    #
    #   chat.pending_questions.select(&:approval?).each { |question| puts question.tool_call.name }
    #
    # #complete carries each call on once nothing it asked waits for an
    # answer. Calls that need no answer still run before the loop pauses.
    # Consults each pending tool's approval resolver when one is declared,
    # so resolvers must be idempotent reads.
    def pending_questions
      response = pending_tool_response
      return [] unless response

      pending_tool_calls(response).flat_map do |tool_call|
        next [Question.approval(tool_call, chat: self)] if approval_pending?(tool_call)

        unanswered_questions(tool_call)
      end
    end

    # Answers +question+, a Question from #pending_questions or its id, as
    # Question#answer describes, and returns +self+. Answering an approval
    # approves its call. Takes the ActionController::Parameters a form
    # sends for several fields, and keeps only the fields the question asks
    # for. A question already answered, or one whose call has finished,
    # stays as it is, so a form sent twice is safe, and of two answers to
    # one approval at once, the first stands. #approve instead records a
    # decision whatever came before.
    #
    #   chat.answer(question, "window")
    #   chat.answer(params[:question_id], params[:answer])
    #   chat.complete
    #
    # Raises ArgumentError for a question the chat never asked, and for an
    # answer the question can't take.
    def answer(question, value = nil, **values)
      pending = pending_question(question)
      response = pending&.response_to(value, values)
      return self unless pending && settle_question(pending, response)

      question.respond(response) if question.is_a?(Question)
      self
    end

    # Declines +question+, a Question from #pending_questions, its id, or
    # the ToolCall of an approval, and returns +self+. A declined
    # approval's call doesn't run: the next #complete or #run_tools gives
    # the model a refusal instead, or sends one for a remote tool on the
    # next request, unless another decision came first, also once the chat
    # no longer offers the call's tool. A tool that asked
    # gets +nil+ from Tool#ask. A +note+ tells the model why: it is the
    # declined approval's result in place of the plain refusal, and it
    # follows the result of a tool whose question was declined. A Hash
    # +note+ is the declined approval's whole result, as given, and
    # follows a tool's result as JSON. A blank note counts as none. A question already answered, or one whose call
    # has finished, stays as it is.
    #
    #   chat.decline(question)
    #   chat.decline(params[:question_id], "The order shipped already")
    #   chat.complete
    #
    # Raises ArgumentError for a question the chat never asked.
    def decline(question, note = nil)
      pending = pending_question(question)
      response = Question.declined(note)
      return self unless pending && settle_question(pending, response)

      question.respond(response) if question.is_a?(Question)
      self
    end

    # Returns whether +tool_call+ requires approval and has no recorded
    # decision.
    def approval_pending?(tool_call) # :nodoc:
      return false if tool_call.malformed_arguments? || skipped_result(tool_call)
      return approval_decision(nil, tool_call).nil? if tool_call.remote?

      tool = tool_for(tool_call)
      return false unless tool&.requires_approval?(tool_call)

      approval_decision(tool, tool_call).nil?
    end

    # Returns the Task objects that tool calls wait on, as they were when
    # the chat last checked, with an MCP::Task for each MCP tool call.
    # Task#refresh checks on one without resuming the chat; #complete
    # resumes every call with Tool#resume.
    #
    #   chat.pending_tasks.each { |task| puts "#{task.tool_call.name}: #{task.status_message}" }
    #
    # A task that is Task#input_required? waits on a person, as the
    # questions in #pending_questions do, so there is no point in checking
    # on it before they act:
    #
    #   notify(chat.owner) if chat.pending_questions.any? || chat.pending_tasks.any?(&:input_required?)
    #
    # Check on the others after their Task#poll_interval:
    #
    #   sleep chat.pending_tasks.first.poll_interval
    #   chat.complete
    #
    def pending_tasks
      response = pending_tool_response
      return [] unless response

      pending_tool_calls(response).filter_map do |tool_call|
        state = tool_call_input(tool_call)
        task_for(tool_call, state) if state&.key?('task') && !unanswered?(state)
      end
    end

    # Cancels the current in-flight chat operation. Every cancellation
    # checkpoint raises CancelledError until the operation ends, so tool
    # calls running concurrently all stop, and the flag is cleared then so
    # the chat can be reused. The tasks that pending tool calls wait on are
    # cancelled then too; see #pending_tasks. Tool calls left without a
    # result are closed as unfinished, so the next #ask can go on and no
    # tool runs twice. A tool that already returned keeps its result. The
    # text a cancelled stream showed stays as a reply that is
    # Message#cancelled?.
    def cancel
      @cancelled = true
      self
    end

    # Returns whether this in-memory chat has been marked for cancellation.
    def cancelled?
      @cancelled
    end

    # Sets the system instructions for the conversation, replacing any
    # existing system messages. With <tt>append: true</tt> the instructions
    # are added alongside the existing ones. With <tt>cache_until_here:
    # true</tt> the instruction becomes an explicit prompt cache boundary;
    # pass <tt>cache_until_here: { ttl: "1h" }</tt> to give that boundary its
    # own lifetime, as Message#cache_until_here describes. Pass +nil+ to
    # remove all system instructions. Returns +self+.
    #
    #   chat.with_instructions "You are a helpful Ruby tutor."
    #   chat.with_instructions "Use exactly one short paragraph.", append: true
    #   chat.with_instructions policy, cache_until_here: { ttl: "1h" }
    #   chat.with_instructions nil
    #
    def with_instructions(instructions, append: false, cache_until_here: false)
      boundary = Message.cache_boundary_options(cache_until_here) if cache_until_here
      @messages.reject! { |message| message.role == :system } unless append
      @messages << Message.new(role: :system, content: instructions) unless instructions.nil?
      @messages.last.cache_until_here(**boundary) if instructions && boundary
      self
    end

    # Registers +tools+, each a Tool class or instance, for the model to
    # call. Configure how the model uses them with #with_tool_options.
    # Pass +nil+ to remove all registered tools. Returns +self+.
    #
    #   chat.with_tools(Weather, Search)
    #   chat.with_tools(Weather).with_tool_options(choice: :required)
    #
    # Pass <tt>defer: true</tt> to keep the tools' definitions out of the
    # model's context until the provider's tool search loads the ones it
    # needs, or <tt>defer: false</tt> to offer a tool declared with
    # Tool.defer up front. See #deferred_tools.
    #
    #   chat.with_tools(*Catalog.tools, defer: true)
    #
    # A namespaced tool is registered under its namespace and name joined,
    # as in <tt>:crm_customer_lookup</tt>. Raises ArgumentError when that
    # key belongs to another tool.
    #
    # To replace the registered tools, clear them first:
    #
    #   chat.with_tools(nil).with_tools(NewTool)
    #
    def with_tools(*tools, defer: nil)
      if tools == [nil]
        @tools.clear
        @tool_deferrals.clear
      end
      tools.flatten.compact.each do |tool|
        tool = tool.to_tool if tool.respond_to?(:to_tool)
        tool = tool.new if tool.is_a?(Class)
        name = tool.qualified_name.to_sym
        existing = @tools[name]
        if existing && [existing.namespace, existing.name.to_s] != [tool.namespace, tool.name.to_s]
          raise ArgumentError, "Two tools are named #{name}. Rename one with `tool :#{name}, as:`"
        end

        @tools[name] = tool
        @tool_deferrals[name] = defer.nil? ? tool.deferred? : defer
      end
      self
    end

    # Returns the tools the model can call, as a Hash of tool name Symbols
    # to Tool instances: those registered with #with_tools and those of the
    # MCP servers connected with #with_mcp. MCP tools that only the UI of
    # an MCP App may call are left out; see MCP::Tool#visibility.
    #
    # A namespaced tool's key joins its namespace and name, as in
    # <tt>:crm_customer_lookup</tt>. Raises ArgumentError when two tools
    # share a key.
    def tools
      offered = @tools.reject { |_, tool| hidden_from_model?(tool) }
      built_in = [@code_execution_tool, (@skill_loader if skills.any?), *@file_tools, tool_search_tool]
      [*built_in, *mcp.reachable_tools].compact.each_with_object(offered) do |tool, tools|
        next if hidden_from_model?(tool)

        name = tool.qualified_name.to_sym
        raise ArgumentError, "Two tools are named #{name}. Rename one with `tool :#{name}, as:`" if tools.key?(name)

        tools[name] = tool
      end
    end

    # Returns the tools whose definitions stay out of the model's context
    # until the provider's tool search loads them, as a Hash like #tools.
    # Providers without tool search receive them as ordinary tools.
    #
    #   chat.with_tools(Weather).with_mcp(GitHub, defer: true)
    #   chat.deferred_tools.keys # => [:search_issues, :create_issue, ...]
    #
    def deferred_tools
      tools.slice(*deferred_tool_names)
    end

    # Connects MCP servers, each an MCP instance or class, and gives the
    # model their tools. The servers are contacted when the chat first
    # needs their tools. Pass +nil+ to disconnect them all. Returns +self+.
    #
    # The chat closes the servers it built from a class when it disconnects
    # them, or when another server takes their name. Instances you pass in
    # stay open: close them with MCP#close.
    #
    #   chat.with_mcp(Linear.new(user: current_user), Files)
    #   chat.mcp.linear
    #
    # Pass <tt>defer: true</tt> to keep every tool of these servers out of
    # the model's context until the provider's tool search loads it, or
    # <tt>defer: false</tt> to offer them up front despite MCP.defer. See
    # #deferred_tools.
    #
    #   chat.with_mcp(GitHub, defer: true)
    #
    def with_mcp(*servers, defer: nil)
      if servers == [nil]
        @mcp.disconnect(self)
        @mcp = MCP::Collection.new
        @mcp_deferrals.clear
      else
        servers.flatten.compact.each do |server|
          server = @mcp.connect(server, self)
          @mcp_deferrals[server.name.to_sym] = defer
        end
      end
      self
    end

    # Enables tools that run on the provider's servers, such as web search
    # or code execution. Accepts portable alias Symbols, alias-with-options
    # keywords whose options use the provider's own vocabulary, and raw
    # Hashes passed to the provider verbatim, so provider tools RubyLLM has
    # no alias for yet work without a gem update. Entries add to any tools
    # enabled earlier. Enabling an alias again replaces its options, and an
    # identical raw Hash or MCP server is not repeated, so a chat sends
    # each tool once. Pass +nil+ to clear them all. Returns +self+.
    #
    #   chat.with_provider_tools(:web_search)
    #   chat.with_provider_tools(:web_search, :code_execution)
    #   chat.with_provider_tools(web_search: { allowed_domains: ["ruby-lang.org"] })
    #   chat.with_provider_tools({ type: "web_search_20260318", name: "web_search" })
    #
    # Raw client-toolset declarations also use this method. Their member
    # calls run through application tools registered with #with_tools and
    # Tool.namespace, and appear in Message#tool_calls.
    #
    # The tool steps the model ran come back on
    # Message#server_tool_calls, citations from search tools on
    # Message#citations, and per-use billing counters on
    # <tt>message.tokens.server_tool_use</tt>.
    #
    # Raises UnsupportedServerToolError at request time when the provider
    # has no provider-tool support or does not define a requested alias.
    def with_provider_tools(*tools, **tools_with_options)
      if tools == [nil] && tools_with_options.empty?
        @provider_tools = []
        return self
      end

      additions = RubyLLM::Tools::ProviderTools.normalize(tools, tools_with_options)
      @provider_tools = RubyLLM::Tools::ProviderTools.merge(@provider_tools, additions)
      self
    end

    # Configures how the model uses the registered tools. +choice:+
    # constrains tool use to +:auto+, +:none+, +:required+, a tool name, or
    # a Tool class. +calls:+ limits how many tool calls one response may
    # contain (+:many+ or +:one+). +concurrency:+ runs tool calls
    # concurrently: +true+ or +:threads+ for threads, +:fibers+ for fibers.
    # An omitted option is left unchanged; passing +nil+ explicitly resets
    # that option (+concurrency: nil+ returns to the configured default).
    # Returns +self+.
    #
    #   chat.with_tools(Weather, Search).with_tool_options(choice: :required)
    #   chat.with_tool_options(calls: :one, concurrency: :threads)
    #   chat.with_tool_options(choice: nil)
    #
    def with_tool_options(**options)
      options.each do |option, value|
        case option
        when :choice then apply_tool_choice(value)
        when :calls then @tool_prefs[:calls] = value.nil? ? nil : normalize_calls(value)
        when :concurrency then apply_tool_concurrency(value)
        else raise ArgumentError, "Unknown tool option: #{option}. Valid options are: choice, calls, concurrency"
        end
      end
      self
    end

    # Switches the chat to +model_id+ and its provider. Pass +provider:+ to
    # disambiguate, and <tt>assume_model_exists: true</tt> to skip registry
    # validation for custom or private models. Pass +nil+ to return to the
    # configured default model. Returns +self+.
    #
    # +protocol:+ overrides the wire protocol the provider would pick for the
    # model, such as +:responses+ or +:chat_completions+ for OpenAI. It stays
    # +nil+ by default, meaning the provider chooses the protocol for each
    # request. A bare #with_model resets the override to +nil+, just as it
    # re-resolves the provider from the model.
    #
    # Raises ModelNotFoundError if +model_id+ is not in the registry and
    # +assume_model_exists:+ is false.
    #
    #   chat.with_model('claude-sonnet-5')
    #   chat.with_model('gpt-6.1-sol', protocol: :chat_completions)
    #
    def with_model(model_id, provider: nil, protocol: nil, assume_model_exists: false)
      model_id ||= @config.default_model
      @model, @provider = Models.resolve(model_id, provider:, assume_model_exists:, config: @config)
      @connection = @provider.connection
      @protocol = protocol
      self
    end

    # Sets fallback models to try, in order, when generation fails. +on:+
    # selects the error classes that trigger a fallback; the default covers
    # transient provider and network errors. Cancelling the chat never
    # triggers a fallback, and neither does another process taking over a
    # persisted chat or an error your streaming block raises. Pass +nil+ to
    # remove all fallbacks and restore the default error classes. Returns
    # +self+.
    #
    #   chat.with_fallbacks("gpt-4.1-mini", "claude-haiku-4-5")
    #   chat.with_fallbacks(nil)
    #
    # With <tt>drop_unsupported: true</tt>, when a model rejects a parameter
    # with UnsupportedParameterError, the chat retries that model without
    # it: the temperature, thinking, the output cap, citations, or a key of
    # #with_provider_options. A model that rejects another parameter is
    # retried without that one too, and each is dropped at most once. The
    # next model starts again from the request as written. The chat keeps
    # its settings for later requests. #before_fallback and
    # #after_fallback receive each retry as a Fallback from the model to
    # itself, whose Fallback#dropped_parameter names the parameter. Without
    # the option, nothing is ever dropped.
    #
    #   chat.with_temperature(0.2).with_fallbacks(drop_unsupported: true)
    #
    def with_fallbacks(*models, on: Fallback::DEFAULT_ERRORS, drop_unsupported: false)
      fallback_models = models.flatten.compact
      @fallbacks = fallback_models.map { |model| Fallback.build(model) }
      @fallback_errors = fallback_models.empty? ? Fallback::DEFAULT_ERRORS : Array(on).flatten.compact
      @drop_unsupported = drop_unsupported
      self
    end

    # Sets the sampling temperature for subsequent requests. Pass +nil+ to
    # return to the model's default sampling behavior. Returns +self+.
    #
    #   chat.with_temperature(0.2)
    #
    def with_temperature(temperature)
      @temperature = temperature
      self
    end

    # Caps the number of tokens the model may generate.
    # Pass +nil+ to remove the limit.
    # Returns +self+.
    #
    #   chat.with_max_output_tokens(1000)
    #
    def with_max_output_tokens(max_output_tokens)
      @max_output_tokens = max_output_tokens
      self
    end

    # Configures extended thinking for models that support it. With no
    # arguments, RubyLLM uses the current model's registered default. Pass
    # +false+ to disable thinking, or tune it with
    # +effort:+ (+:low+, +:medium+, +:high+, +:none+, or a
    # provider-specific tier such as +:minimal+, +:xhigh+, or +:max+,
    # passed through as-is), +budget:+ (a token count), and +display:+
    # (+:summarized+ or +:omitted+, controlling whether providers that
    # support it return readable thinking text). Accepts keywords or an options
    # Hash. Passing +nil+ raises ArgumentError. Returns +self+.
    #
    #   chat.with_thinking
    #   chat.with_thinking(false)
    #   chat.with_thinking(effort: :high)
    #   chat.with_thinking(budget: 10_000)
    #   chat.with_thinking(display: :summarized)
    #
    def with_thinking(enabled = true, **options) # rubocop:disable Metrics/PerceivedComplexity
      return with_thinking(**enabled.transform_keys(&:to_sym), **options) if enabled.is_a?(Hash)

      raise ArgumentError, 'with_thinking accepts false or thinking options' unless [true, false].include?(enabled)
      raise ArgumentError, 'with_thinking(false) does not accept options' if !enabled && options.any?
      raise ArgumentError, 'thinking options cannot be nil; pass false to disable' if options.value?(nil)
      if (unsupported = options.keys - THINKING_OPTIONS).any?
        raise ArgumentError,
              "with_thinking accepts #{format_option_keys(THINKING_OPTIONS)}, " \
              "got #{format_option_keys(unsupported)}"
      end

      @thinking = if enabled
                    options.empty? ? Thinking::Config.default : Thinking::Config.new(**options)
                  else
                    Thinking::Config.disabled
                  end
      self
    end

    # Returns the thinking options resolved for the current model, or +nil+
    # when thinking was not configured or needs no provider control. When
    # the model registry has no thinking controls for the model, returns
    # the request itself, <tt>{ enabled: true }</tt> or
    # <tt>{ enabled: false }</tt>; the request then raises ArgumentError.
    def thinking
      config = @thinking&.resolve(@model, strict: false)
      return unless config

      {
        effort: config.effort,
        budget: config.budget,
        display: config.display,
        enabled: config.enabled
      }.compact
    end

    # Enables document citations, so the model backs its claims with quotes
    # from attached files. Pass +false+ to disable. Passing +nil+ raises
    # ArgumentError. Returns +self+.
    #
    #   chat.with_citations
    #   response = chat.ask "Who created Ruby?", with: "facts.txt"
    #   response.citations.each { |citation| puts citation.cited_text }
    #
    def with_citations(enabled = true)
      raise ArgumentError, 'with_citations accepts true or false' unless [true, false].include?(enabled)

      @citations = enabled
      self
    end

    # Enables provider prompt caching. With no arguments the provider's
    # default behavior applies; options apply where supported. +ttl:+ is
    # a lifetime as a provider String, seconds, or a Duration. Pass a
    # CachedContent from RubyLLM.cache to attach an explicit content cache,
    # or +id:+ with its name. Pass +false+ to stop RubyLLM from sending cache
    # controls or rendering explicit cache boundaries. A provider may still
    # cache prompts implicitly. Passing +nil+ raises ArgumentError.
    # Returns +self+.
    #
    #   chat.with_caching
    #   chat.with_caching(ttl: "1h")
    #   chat.with_caching(ttl: 1.hour)
    #   chat.with_caching(cache)
    #   chat.with_caching(false)
    #
    def with_caching(options = {})
      options = {} if options == true
      options = { id: options } if options.is_a?(CachedContent)
      unless options == false || options.is_a?(Hash)
        raise ArgumentError, 'with_caching accepts true, false, a CachedContent, or caching options'
      end

      @caching = options == false ? false : options.transform_keys(&:to_sym).freeze
      self
    end

    # Enables provider-side context compaction, so a long conversation keeps
    # going instead of overflowing the context window. The provider condenses
    # the earlier turns itself and returns a block that RubyLLM replays on
    # later requests. With no arguments the provider's own defaults apply.
    # The options are provider-neutral:
    #
    # +at+:: the input-token count that triggers compaction.
    # +instructions+:: a custom prompt for the summary the provider writes.
    # +pause_after+:: end the turn once compaction runs, instead of
    #                 continuing straight into the answer.
    #
    # Each provider applies the options it supports. Unsupported options
    # are ignored with a debug log. Pass +false+ to disable; passing +nil+
    # raises ArgumentError. Returns +self+.
    #
    #   chat.with_compaction
    #   chat.with_compaction(at: 50_000)
    #   chat.with_compaction(at: 100_000, instructions: "Keep every decision.")
    #   chat.with_compaction(false)
    #
    # What a provider does when the threshold is crossed differs. Anthropic
    # and OpenAI summarize the compacted span into an opaque block that
    # replaces it; OpenRouter drops messages from the middle of the
    # conversation instead, and has no threshold of its own.
    def with_compaction(options = {})
      options = {} if options == true
      unless options == false || options.is_a?(Hash)
        raise ArgumentError, 'with_compaction accepts true, false, or compaction options'
      end

      @compaction = options == false ? false : normalize_compaction(options)
      self
    end

    # Keeps tool results within shares of the model's context window, from
    # the model registry, in place of Configuration#context_budget. Pass
    # +nil+ to remove the budget. Returns +self+.
    #
    # +per_result+:: a tool result longer than this share is cut when it
    #                is added, ending with a note that tells the model to
    #                ask for less.
    # +per_request+:: when a request would take more than this share, the
    #                 oldest tool results are left out of what is sent,
    #                 each replaced by a one-line note. The transcript
    #                 keeps them. The results of the latest round go out
    #                 whenever they fit. The cut point moves in steps, so
    #                 the request prefix, and the provider's prompt cache,
    #                 hold for many rounds.
    #
    # +window+:: the context window in tokens, for a model the registry
    #            has no window for. It wins over the registry's.
    #
    #   chat.with_context_budget(per_result: 0.25, per_request: 0.7)
    #   chat.with_context_budget(window: 128_000, per_request: 0.7)
    #
    # Shares are above 0 and at most 1. Sizes are estimated from
    # characters, at two a token. A result a file store already saved as
    # a file (see #with_file_store) is short enough to keep. Without a
    # known window the budget does nothing, and the chat logs a warning
    # once.
    def with_context_budget(budget = {}, **shares)
      @context_budget = ContextBudget.normalize(budget, **shares)
      @context_budget_chosen = true
      @context_budget_warned = false
      self
    end

    # Lets the model run code in a Sandbox. The model gets one tool,
    # +run_code+, that runs Ruby, Python, JavaScript, or a shell script in a fresh run
    # directory, with read-only copies of the conversation's files, and
    # returns the output and every file the code writes there as
    # attachments on the tool result. With #with_file_store, runs work with
    # the chat's files instead: with FileStore::Directory, in the store's
    # folder, where attachments are at their own paths. With other stores,
    # runs still have read-only copies of the conversation's files
    # in +attachments/+, copy in the other files the model names, and what
    # the code writes is saved back. The options are:
    #
    # +sandbox+:: the sandbox every call runs in. Default:
    #             Configuration#sandbox.
    # +escalate_to+:: sandboxes the model may ask for, one call at a time,
    #                 as an Array named after their classes
    #                 (WorkspaceSandbox is +workspace+) or a Hash of names
    #                 to sandboxes. Each call that asks waits for #approve.
    # +languages+:: the languages the model may use, from +:ruby+,
    #               +:python+, +:javascript+, and +:shell+. Default: Ruby
    #               and shell, plus Python and JavaScript when their
    #               packages are declared.
    # +gems+:: gems installed once and available to every Ruby run.
    # +python+:: Python packages installed once and available to every
    #            Python run.
    # +npm+:: npm packages installed once, without their install scripts,
    #         and available to every JavaScript run.
    # +gem_home+:: a GEM_HOME with gems already installed, used instead
    #              of +gems+.
    # +virtualenv+:: a Python virtualenv with packages already installed,
    #                used instead of +python+.
    # +node_modules+:: a +node_modules+ directory with packages already
    #                  installed, used instead of +npm+.
    # +mounts+:: directories mounted read-only in each run directory, keyed
    #            by their path there, or a Proc called before each run
    #            that returns them.
    #
    # Accepts keywords or an options Hash. Pass +false+ to disable it.
    # Passing +nil+ raises ArgumentError. Returns +self+.
    #
    #   chat.with_code_execution
    #   chat.with_code_execution(gems: %w[prawn], python: %w[pandas matplotlib])
    #   chat.with_code_execution(sandbox: ReadOnlySandbox, escalate_to: [WorkspaceSandbox, OnlineSandbox])
    #   chat.with_code_execution(mounts: { "templates" => "app/templates/reports" })
    #   chat.with_code_execution(false)
    #
    # Raises ConfigurationError when no sandbox is configured. Code never
    # runs outside a sandbox. To run code on the provider's servers
    # instead, use <tt>with_provider_tools(:code_execution)</tt>.
    def with_code_execution(enabled = true, **options)
      options = CodeExecution.options(enabled, options)
      @code_execution_tool = if options
                               CodeExecution.new(
                                 sandbox: options[:sandbox],
                                 attachments: -> { messages.flat_map(&:attachments) },
                                 file_store: -> { file_store },
                                 attached_files: -> { @file_references&.attached_files(messages).to_a },
                                 written: ->(file) { run_callbacks(:after_file_write, file) },
                                 skills: -> { skills.to_h { |skill| [Skill::Loader.mount_path(skill), skill.path] } },
                                 chat: self,
                                 config: -> { @config },
                                 package_cache_dir: @config.package_cache_dir,
                                 approval: ->(tool_call) { escalation_approved?(tool_call) },
                                 **options.except(:sandbox)
                               )
                             end
      @code_execution = options
      self
    end

    # Gives the model skills: folders of instructions, scripts, and files
    # in the open Agent Skills format. Called bare or with +true+, adds
    # every skill directly under Skill.roots, +app/skills+ by default.
    # Symbols name folders under the roots, and Strings and Pathnames are
    # paths to skill folders. Pass +false+ to remove every skill. Passing
    # +nil+ raises ArgumentError. Returns +self+.
    #
    #   chat.with_skills
    #   chat.with_skills(:invoices, :reports)
    #   chat.with_skills(:invoices, "vendor/skills/pdf")
    #   chat.with_skills(false)
    #
    # Every request lists each skill's name and description, and the model
    # loads a skill's instructions and files with its +load_skill+ tool.
    # With #with_code_execution, each skill folder is mounted read-only in
    # every run at <tt>skills/<name>/</tt>, so the model can run the
    # skill's scripts.
    #
    # Raises SkillNotFoundError for a missing skill, InvalidSkillError for
    # a +SKILL.md+ that breaks the specification, and ArgumentError when
    # two skills share a name.
    def with_skills(*skills)
      selection = Skill.selection(skills)
      @skills = selection == false ? [] : Skill.merge(@skills, Skill.resolve(selection)).freeze
      self
    end

    # Attaches +store+ to the chat and gives the model tools to work
    # with it: +list_files+, +read_file+, and +search_files+ to find and
    # read files, and +write_file+ and +edit_file+ to change them. Files
    # stop filling the conversation:
    #
    # * Every attachment is kept in the store. The model sees the files
    #   attached to the latest question, and those it opens with
    #   +read_file+, in full until the next question; after that, and for
    #   files other tools return, it sees one line naming the file.
    # * A tool result longer than +inline_limit+ characters is saved under
    #   +results/+, and the model gets its start and the file's path.
    # * +write_file+ and +edit_file+ change only a file the model read, as
    #   it is now, so the model never writes over a change it hasn't seen.
    # * With #with_code_execution, code runs in the store's folder when it
    #   has one, such as FileStore::Directory, changing the files in place.
    #   With other stores, each run has read-only copies of the attachments
    #   in +attachments/+, copies in the files the model names to change or
    #   read, and what the code writes is saved back to the store.
    #
    # +store+ is a folder path, for a FileStore::Directory, +:memory+, for a
    # new FileStore::Memory, or a FileStore. Without it, the chat gets a new
    # FileStore::Memory, or for a persisted chat, its files in Active Storage.
    #
    # +inline_limit+ is the characters a tool result may have and still go
    # to the model whole, or +false+ to send every result whole; tools can
    # set their own with Tool.inline_limit. Default: 10,000.
    #
    # +tools+ names the tools the model gets: +:read+ for +list_files+,
    # +read_file+, and +search_files+, and +:write+, +:edit+, and
    # +:delete+ for +write_file+, +edit_file+, and +delete_file+. Default:
    # <tt>%i[read write edit]</tt>. Raises ArgumentError without +:read+,
    # since older attachments and long results reach the model through it.
    #
    # Pass +nil+ to remove the store and its tools. Returns +self+.
    #
    #   chat.with_file_store
    #   chat.with_file_store("tmp/chats/42")
    #   chat.with_file_store(:memory)
    #   chat.with_file_store(RubyLLM::FileStore::Directory.new("tmp/chats/42"))
    #   chat.with_file_store(inline_limit: 20_000)
    #   chat.with_file_store(tools: :read)
    #   chat.with_file_store(tools: %i[read write edit delete])
    #   chat.with_file_store(nil)
    #
    # Text files are read as text; register converters, such as the OCR
    # converter for PDFs and images, in Configuration#file_converters to
    # read more.
    def with_file_store(store = :memory, inline_limit: FileReferences::INLINE_LIMIT, tools: FileStore::Tools::DEFAULT)
      FileReferences.validate(store, inline_limit:, tools:) unless store.nil?
      store = FileReferences.resolve(store)
      @file_references&.forget(@attachment_replacements)
      @file_references = if store
                           FileReferences.new(store:, inline_limit:, tools:, config: -> { @config },
                                              written: ->(file) { run_callbacks(:after_file_write, file) })
                         end
      @file_tools = store ? build_file_tools : []
      self
    end

    # Returns the FileStore attached with #with_file_store, or +nil+
    # without one.
    #
    #   chat.file_store.list
    #   chat.file_store.read("notes/plan.md")
    def file_store
      @file_references&.store
    end

    # Identifies the end user behind the conversation for the provider's
    # abuse monitoring. Providers without an equivalent field omit it.
    # Pass +nil+ to remove it.
    # Returns +self+.
    #
    #   chat.with_end_user("user-123").ask "Hello"
    #
    # The value is sent as given, so use an opaque id such as a hash of
    # your user id, never personal data.
    def with_end_user(end_user)
      @end_user = end_user
      self
    end

    # Attributes the usage of every attempt the chat makes to +owner+, such
    # as a user or an account record: each request, the tools it runs, the
    # file converters it triggers, and compaction. In Rails, the usage
    # ledger stores the owner with each row; everywhere, the
    # +usage.ruby_llm+ event carries it. It wins over RubyLLM.with_owner,
    # and over the owner a persisted chat's record names. Pass +nil+ to
    # remove it. Returns +self+.
    #
    #   chat.with_owner(current_user).ask "Summarize this thread"
    #
    # RubyLLM never sends the owner to the provider; see #with_end_user
    # for the identifier providers receive.
    def with_owner(owner)
      @owner = owner
      self
    end

    # Rebinds the chat to +context+, a Context built with RubyLLM.context,
    # so subsequent requests use its configuration. Pass +nil+ to return to
    # the global RubyLLM.config. Returns +self+.
    def with_context(context)
      @context = context
      @config = context&.config || RubyLLM.config
      @file_references&.forget(@attachment_replacements)
      with_model(@model.id, provider: @provider.slug, protocol: @protocol, assume_model_exists: true)
      apply_tool_concurrency(nil) unless @concurrency_chosen
      @context_budget = @config.context_budget unless @context_budget_chosen
      self
    end

    # Sets options in the provider's request vocabulary, merged into the
    # request payload as-is and overriding RubyLLM's defaults. Replaces any
    # previously set provider options; +nil+ clears them. Returns +self+.
    #
    #   chat.with_provider_options(service_tier: "flex")
    #
    def with_provider_options(provider_options)
      @provider_options = provider_options.to_h
      self
    end

    # Sets extra HTTP headers sent with completion requests, replacing any
    # previously set headers; +nil+ clears them. Returns +self+. The
    # provider's own headers, such as authentication and API version
    # headers, win over a header of the same name set here.
    #
    #   chat.with_headers('anthropic-beta' => 'fine-grained-tool-streaming-2025-05-14')
    #
    def with_headers(headers)
      @headers = headers.to_h
      self
    end

    # Sets the schema for structured output. Accepts a JSON Schema Hash, a
    # Schematist::Schema class or instance, or any object responding to
    # +to_json_schema+. Returns +self+.
    #
    #   class PersonSchema < Schematist::Schema
    #     string :name
    #     integer :age
    #   end
    #
    #   chat.with_schema(PersonSchema)
    #   response = chat.ask("Generate a person named Alice who is 30 years old")
    #   response.parsed # => {"name" => "Alice", "age" => 30}
    #
    # Pass +nil+ to remove the schema, returning the chat to plain text
    # responses.
    def with_schema(schema)
      schema_instance = schema.is_a?(Class) ? schema.new : schema

      @schema = normalize_schema_payload(
        schema_instance.respond_to?(:to_json_schema) ? schema_instance.to_json_schema : schema_instance
      )

      self
    end

    # Registers a callback that runs before each assistant response or tool
    # result is appended to the conversation. Callbacks are additive: every
    # registered block runs. Returns +self+.
    def before_message(&)
      add_callback(:before_message, &)
    end

    # Registers a callback that receives each assistant response, each
    # tool result message, and each user message a queued message becomes,
    # once it has been appended. Returns +self+.
    #
    #   chat.after_message { |message| puts message.content }
    #
    def after_message(&)
      add_callback(:after_message, &)
    end

    # Registers a callback that wraps the moment each queued message joins
    # the conversation. It receives the QueuedMessage and +join+, and runs
    # in the loop's thread. <tt>join.call</tt> adds the user Message and
    # returns it. Returns +self+.
    #
    #   chat.around_join do |queued, join|
    #     message = join.call
    #     audit_log << [queued.sender, message.content]
    #   end
    #
    # A block that never calls +join+ withdraws the message: it leaves the
    # queue without joining, and the turn goes on. A block that raises
    # leaves the message queued and out of the conversation. Several
    # blocks nest in the order they were registered, the first outermost,
    # and #after_message runs once they all return.
    # When an inner block withdraws the message, <tt>join.call</tt> in an
    # outer block returns +nil+.
    #
    # On a persisted chat, the block runs inside the transaction that
    # creates the message record and deletes the queued one, and
    # <tt>join.call</tt> takes attributes for the new record, such as
    # columns of your own. See RubyLLM::ActiveRecord::ChatMethods. A plain
    # chat has no such columns, so its +join+ raises ArgumentError when
    # given attributes. Registering the same block again does nothing.
    def around_join(&block)
      return self if @callbacks[:around_join].include?(block)

      add_callback(:around_join, &block)
    end

    # Registers a callback that receives each local ToolCall before the tool
    # executes. Returns +self+.
    #
    #   chat.before_tool_call { |tool_call| puts tool_call.name }
    #
    def before_tool_call(&)
      add_callback(:before_tool_call, &)
    end

    # Registers a callback that wraps each local tool's execution. It
    # receives the ToolCall and a block, +run+, that runs the tool and
    # returns its result. Returns +self+.
    #
    #   chat.around_tool_call { |tool_call, &run| ActsAsTenant.with_tenant(account, &run) }
    #
    # The block runs in the thread or fiber that runs the tool, so
    # fiber-local state, +Current+ attributes, and tenants it sets reach the
    # tool, also with concurrent tool execution. It runs after
    # #before_tool_call and before #after_tool_result. Several blocks nest
    # in the order they were registered, the first outermost. The result is
    # the tool's, whatever the block returns. A block that never calls
    # +run+ skips the tool, and the model is told the call did not run.
    def around_tool_call(&)
      add_callback(:around_tool_call, &)
    end

    # Registers a callback that receives each local tool's result after
    # execution. Returns +self+.
    def after_tool_result(&)
      add_callback(:after_tool_result, &)
    end

    # Registers a callback that receives the ToolCall and a Progress each
    # time a running local tool reports what it is doing, with
    # Tool#progress or, for MCP tools, through the server's progress
    # notifications. Returns +self+.
    #
    #   chat.after_tool_progress do |tool_call, progress|
    #     puts "#{tool_call.name}: #{progress.message}"
    #   end
    #
    # The callback runs in the thread or fiber that reports, before the
    # tool's result. On Ruby 3.2 and later, that includes threads and
    # fibers the tool starts. With concurrent tool execution, callbacks for
    # different tool calls can run at the same time.
    def after_tool_progress(&)
      add_callback(:after_tool_progress, &)
    end

    # Registers a callback that receives each StoredFile the conversation
    # writes to the chat's FileStore (see #with_file_store): attachments as they
    # are kept, long tool results, and the files tools and code write.
    def after_file_write(&)
      add_callback(:after_file_write, &)
    end

    # Registers a callback that receives the Fallback attempt after the
    # current model fails and before the next model is tried, or the same
    # model again without a parameter it rejected. Returns +self+.
    def before_fallback(&)
      add_callback(:before_fallback, &)
    end

    # Registers a callback that receives the Fallback attempt once it has
    # succeeded or failed. Returns +self+.
    def after_fallback(&)
      add_callback(:after_fallback, &)
    end

    # Registers a callback that receives the fully rendered request payload
    # before it is sent and may mutate it in place. Runs after all RubyLLM
    # formatting and #with_provider_options merging. Returns +self+.
    #
    #   chat.before_request { |payload| logger.debug payload }
    #
    def before_request(&)
      add_callback(:before_request, &)
    end

    # Converts attachments the current protocol cannot render with the
    # given block. Returns +self+. The block receives an Attachment and
    # returns a replacement Attachment, or +nil+ to keep the existing error.
    # Blocks run in registration order until one returns a replacement.
    # The transcript keeps the original file, even when the model changes.
    # The chat converts each attachment once and reuses the replacement,
    # and its upload, on later requests.
    #
    #   chat.convert_unsupported_attachments do |attachment|
    #     text = TextExtraction.call(attachment)
    #     Attachment.new(StringIO.new(text), filename: 'extracted.txt') if text
    #   end
    def convert_unsupported_attachments(&)
      add_callback(:unsupported_attachment, &)
    end

    # Deprecated: iterate #messages instead. Yields each Message in the
    # conversation, or returns an Enumerator without a block. The
    # Enumerable methods built on it, such as +map+ and +count+, are
    # deprecated with it. Warns through RubyLLM.deprecator. RubyLLM 3.0
    # removes them.
    #
    #   chat.messages.each { |message| puts message.content }
    #
    def each(&)
      RubyLLM.deprecator.deprecate("Enumerable on #{self.class}", replacement: "#{self.class}#messages",
                                                                  removal: '3.0')
      messages.each(&)
    end

    # Returns token usage aggregated across every provider attempt this chat
    # has made, including retries and attempts that produced no message.
    #
    #   chat.tokens.input
    #
    def tokens
      Tokens.aggregate(usage_entries.map(&:tokens))
    end

    # Returns a Cost aggregating every provider attempt this chat has made,
    # including retries and attempts that produced no message.
    #
    #   chat.cost.total
    #
    def cost
      Cost.aggregate(usage_entries.map(&:cost), complete: usage_entries.all?(&:cost_available?))
    end

    # Counts input tokens for the conversation, including instructions,
    # function tools, structured output, thinking, and attachments.
    # Pass +message+ to include it as a staged user message without
    # mutating the chat. Returns an Integer.
    #
    #   chat.with_instructions("Be terse.").with_tools(Weather)
    #   chat.count_tokens("What's the weather in Berlin?")
    #
    # Provider tools, provider_options, compaction, and before_request hooks
    # are not included. Raises Error when the provider has no token counting
    # endpoint.
    def count_tokens(message = nil)
      request_messages = messages.dup
      request_messages << coerce_message(role: :user, content: message) unless message.nil?
      @provider.count_tokens(
        preprocessed_messages(request_messages),
        model: @model,
        tools: request_tools,
        tool_prefs: @tool_prefs,
        thinking: resolved_thinking,
        schema: @schema,
        citations: @citations,
        caching: request_caching,
        protocol: @protocol
      )
    end

    # Compacts the conversation's model context and returns an assistant
    # Message. The message can have empty text and carries the provider's
    # compacted context internally. Every earlier message remains in
    # #messages, including on persisted Rails chats.
    #
    #   chat.ask "Remember these project requirements..."
    #   chat.compact
    #   chat.ask "Which requirement should we implement first?"
    #
    # Uses the current instructions, headers, and request hooks. Records
    # reported usage and runs the normal message callbacks. Raises Error
    # when the provider has no manual compaction endpoint, and
    # PendingToolCallsError until pending tool calls have been answered.
    def compact
      raise_if_cancelled!
      raise_if_pending_tool_calls!
      usage_start = usage_entries.length
      payload = instrumentation_payload(streaming: false)
      RubyLLM.instrument('compaction.ruby_llm', payload, config: @config) do |event|
        result = provider_compaction
        record_out_of_band_usage(result) if usage_entries.length == usage_start
        record_generated_message(result, usage_start, keep_unfinished: true)
        record_completion_event(event, result)
        result
      end
    rescue CancelledError
      @cancelled = false
      raise
    end

    # Replaces the conversation with +new_messages+, coercing each element
    # into a Message. Accepts Message objects, attribute Hashes, and
    # records responding to +to_llm+.
    def messages=(new_messages)
      @messages = message_list(new_messages).map { |message| coerce_message(message) }
    end

    # Replaces the usage ledger. Used by the Rails integration when
    # rebuilding a persisted chat.
    def usage_entries=(entries) # :nodoc:
      @usage_entries = Array(entries)
    end

    # Hooks installed by the Rails integration.
    attr_writer :run, :message_queue, :tool_call_state # :nodoc:

    # The Agent class that configured the chat, which its instrumentation
    # events name.
    attr_accessor :agent_class # :nodoc:

    # Runs the block inside one +agent.ruby_llm+ event when an Agent
    # configured the chat, unless a run of this chat is already open. Fibers
    # and threads started during a run inherit its marker, which is emptied
    # when the run ends, so their later turns open events of their own.
    def running_agent(&) # :nodoc:
      return yield if @agent_class.nil? || Fiber[AGENT_RUN_KEY]&.first.equal?(self)

      previous = Fiber[AGENT_RUN_KEY]
      Fiber[AGENT_RUN_KEY] = run = [self]
      begin
        payload = { agent_name: @agent_class.name, chat: self, agent_description: @agent_class.description,
                    chat_id: @run.chat_id }
        payload.delete_if { |key, value| value.nil? && key != :agent_name }
        RubyLLM.instrument('agent.ruby_llm', payload, config: @config, &)
      ensure
        run.clear
        Fiber[AGENT_RUN_KEY] = previous
      end
    end

    # Appends a message to the conversation and returns it as a Message.
    # Accepts a Message, an attribute Hash, or a record responding to
    # +to_llm+.
    #
    #   chat.add_message(role: :user, content: "What's the capital of France?")
    #
    def add_message(message_or_attributes)
      message = prepare_message(message_or_attributes)
      messages << message
      message
    end

    def prepare_message(message_or_attributes, &taken) # :nodoc:
      message = coerce_message(message_or_attributes)
      return ToolCallIds.answer(message, messages) if message.tool_result?
      return message unless message.tool_call?
      return message if message.tool_calls.none? { |call| reused_tool_call_id?(call.id, &taken) }

      ToolCallIds.new.assign(message)
    end

    # Deprecated: mark the message itself with Message#cache_until_here, or
    # pass +cache_until_here:+ to #with_instructions. Marks the latest
    # message as an explicit prompt cache boundary. Warns through
    # RubyLLM.deprecator. RubyLLM 3.0 removes it. Returns +self+.
    #
    #   chat.with_instructions(policy, cache_until_here: { ttl: "1h" })
    #   chat.add_message(role: :user, content: handbook).cache_until_here
    #
    # Raises ArgumentError if the chat has no messages.
    def cache_until_here(ttl: nil)
      RubyLLM.deprecator.deprecate("#{self.class}#cache_until_here",
                                   replacement: 'Message#cache_until_here or with_instructions(cache_until_here:)',
                                   removal: '3.0')
      message = messages.last
      raise ArgumentError, 'No messages to cache' unless message

      message.cache_until_here(ttl:)
      self
    end

    # Receives a completion produced out-of-band (e.g. by a batch), running the
    # same callbacks as a synchronous completion so persistence works unchanged.
    def add_completion(response, record_usage: false) # :nodoc:
      if response.ruby_llm_usage_entries.empty?
        record_out_of_band_usage(response)
      elsif record_usage
        response.ruby_llm_usage_entries.each { |entry| record_usage_entry(entry) }
      end
      run_callbacks(:before_message)
      response = add_message(response)
      run_callbacks(:after_message, response)
      response
    end

    def add_usage_entry(entry) # :nodoc:
      record_usage_entry(entry)
    end

    # Returns the request payload this chat would send to the provider for
    # its next completion, with #before_request hooks applied. Useful for
    # inspecting and testing request output.
    def render
      @provider.render(
        preprocessed_messages,
        tools: request_tools,
        provider_tools: @provider_tools,
        tool_prefs: @tool_prefs,
        temperature: @temperature,
        max_output_tokens: @max_output_tokens,
        model: @model,
        provider_options: Support::Utils.deep_dup(@provider_options),
        schema: @schema,
        thinking: resolved_thinking,
        citations: @citations,
        caching: request_caching,
        compaction: @compaction,
        end_user: @end_user,
        protocol: @protocol,
        before_request: @callbacks[:before_request]
      )
    end

    # Refuses attachments an MCP::Prompt has no place for. Called by
    # #ask_later here and in the Rails integration.
    def raise_if_prompt_attachments!(message, with) # :nodoc:
      return unless message.is_a?(MCP::Prompt) && with && with != []

      raise ArgumentError, 'An MCP::Prompt carries its own messages, so it takes no attachments'
    end

    # Refuses to stage a user message onto an unfinished tool round, which
    # providers reject. Called by #ask_later here and in the Rails
    # integration before it persists anything.
    def raise_if_pending_tool_calls! # :nodoc:
      response = pending_tool_response
      return unless response

      names = pending_tool_calls(response).map(&:name).uniq
      raise PendingToolCallsError,
            "The last response has unanswered tool calls (#{names.join(', ')}). " \
            'Run complete, answering their questions (see pending_questions) and waiting for ' \
            'their tasks, before asking again.'
    end

    private

    def agent_run_chat = self

    def agent_fields
      name = @agent_class&.name
      name ? { agent_name: name } : {}
    end

    def build_skill_loader
      Skill::Loader.new(skills: -> { @skills }, code_execution: -> { !@code_execution_tool.nil? })
    end

    def build_file_tools
      written = ->(file) { run_callbacks(:after_file_write, file) }
      FileStore::Tools.classes(@file_references.tools)
                      .map { |tool| tool.new(store: -> { file_store }, config: -> { @config }, written:) }
    end

    def resolved_thinking
      @thinking&.resolve(@model)
    end

    def request_caching
      return @caching unless @caching.is_a?(Hash)

      caching = @caching
      caching = @provider.fallback_caching(caching, model: @model, protocol: @protocol) if @answering_fallback
      key = @run.cache_key
      return caching if key.nil? || @caching.key?(:key) || !@provider.cache_key?(model: @model, protocol: @protocol)

      caching.merge(key:)
    end

    def normalize_compaction(options)
      compaction = options.to_h.transform_keys(&:to_sym)
      unsupported = compaction.keys - COMPACTION_OPTIONS
      return compaction.freeze if unsupported.empty?

      raise ArgumentError,
            "with_compaction accepts #{format_option_keys(COMPACTION_OPTIONS)}, " \
            "got #{format_option_keys(unsupported)}. Provider-specific settings " \
            'go through with_provider_options.'
    end

    def format_option_keys(keys)
      keys.map { |key| ":#{key}" }.join(', ')
    end

    def message_list(new_messages)
      return [] if new_messages.nil?
      if new_messages.is_a?(Hash) || new_messages.is_a?(Message) || new_messages.respond_to?(:to_llm)
        return [new_messages]
      end

      new_messages.respond_to?(:to_a) ? new_messages.to_a : [new_messages]
    end

    def coerce_message(message_or_attributes)
      raise ArgumentError, 'Message cannot be nil' if message_or_attributes.nil?

      message = if message_or_attributes.respond_to?(:to_llm)
                  message_or_attributes.to_llm
                else
                  message_or_attributes
                end

      message = Message.new(message.merge(config: @config)) unless message.is_a?(Message)
      message.conversation = self
      message
    end

    def normalize_schema_payload(raw_schema)
      return nil if raw_schema.nil?
      return raw_schema unless raw_schema.is_a?(Hash)

      schema = RubyLLM::Support::Utils.deep_symbolize_keys(raw_schema)
      schema_def = extract_schema_definition(schema)
      strict = extract_schema_strict(schema, schema_def)
      build_schema_payload(schema, schema_def, strict)
    end

    def extract_schema_definition(schema)
      definition = RubyLLM::Support::Utils.deep_dup(schema[:schema] || schema)
      RubyLLM::Support::Utils.strip_schema_metadata(definition)
    end

    def extract_schema_strict(schema, schema_def)
      return schema[:strict] if schema.key?(:strict)
      return schema_def.delete(:strict) if schema_def.is_a?(Hash)

      nil
    end

    def build_schema_payload(schema, schema_def, strict)
      {
        name: sanitize_schema_name(schema[:name] || schema[:title] || 'response'),
        schema: schema_def,
        strict: strict,
        description: schema[:description]
      }.compact
    end

    def sanitize_schema_name(name)
      sanitized = name.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
      sanitized.empty? ? 'response' : sanitized
    end

    def add_callback(name, &block)
      @callbacks[name] << block if block
      self
    end

    def raise_if_cancelled!
      @cancelled = true if @run.cancellation_requested?
      raise CancelledError if @cancelled
    end

    # The transport retries through the checkpoint, so a cancelled request
    # stops at its failure. A chat cancelled while a request failed was going
    # to stop anyway, so the cancellation is what the caller hears about.
    def cancellable_request(&)
      Support::Cancellation.watch(-> { raise_if_cancelled! }, &)
    rescue Error
      raise_if_cancelled!
      raise
    end

    def build_message_queue(queued = [])
      MessageQueue.new(queued) do |message|
        run_around_join(message) do |**attributes|
          raise ArgumentError, 'join takes attributes only on a persisted chat' if attributes.any?

          add_message(role: :user, content: message.content, attachments: message.attachments)
        end
      end
    end

    def advance(steering_only:, &)
      return if settled?(steering_only)

      raise_if_cancelled!
      take_queued_messages(steering_only:) unless pending_tool_response
      return if answered?
      return generate(&) unless pending_tool_response

      before = messages.length
      run_tools
      messages.last if messages.length > before
    rescue CancelledError
      stop_tool_round
      raise
    end

    # A round can stall once while another process lets its claim go, and
    # goes on the next time, perhaps to pause. A second stall in a row that
    # leaves nothing to wait on would repeat forever.
    def stalled_round?(stalled, generated:, move:)
      return false if generated || move
      return true unless stalled && !waiting?

      ids = pending_tool_response&.then { |response| pending_tool_calls(response).keys }
      raise StalledToolRound,
            "RubyLLM made no progress on tool calls #{Array(ids).join(', ')}: they neither ran nor wait"
    end

    def stop_tool_round
      @cancelled = false
      cancel_tasks
      close_unstarted_tool_calls
    end

    def settled?(steering_only)
      answered? && @message_queue.none?(steering_only:)
    end

    def last_conversation_message
      messages.reverse.find { |message| message.role != :system && !placeholder?(message) }
    end

    def answered?
      return false if pending_tool_response

      last = last_conversation_message
      case last&.role
      when nil then true
      when :user then false
      when :tool then !halted_result.nil? || last.cancelled?
      else !last.tool_call? && !unfinished?(last)
      end
    end

    # A tool that halted ends the turn once its round has every result.
    def halted_result
      messages.reverse_each.take_while(&:tool_result?).find(&:halted?)
    end

    def generate_once(stream_tracker: nil, usage_start: nil, &)
      usage_start ||= usage_entries.length
      resumed = unfinished?(messages.last)
      streamed = +''
      tracker = proc do |chunk|
        streamed << chunk.content if chunk.content.is_a?(String)
        stream_tracker&.call(chunk)
      end
      generate_attempt(stream_tracker: tracker, usage_start:, &)
    rescue CancelledError
      keep_cancelled_reply(streamed, usage_start) unless resumed
      raise
    end

    def generate_attempt(stream_tracker:, usage_start:, &block)
      raise_if_cancelled!

      result = nil
      entries_before = usage_entries.length
      payload = instrumentation_payload(streaming: block_given?)
      announced = block_given?
      resumed = messages.last if unfinished?(messages.last)
      progress = proc do |partial|
        run_callbacks(:before_message) unless announced
        announced = true
        record_progress(partial)
      end

      RubyLLM.instrument('chat.ruby_llm', payload, config: @config) do |event|
        result = provider_completion(usage_recorder: method(:record_usage_entry), progress_recorder: progress,
                                     stream_tracker:, &block)
        event[:response_tokens] = result.tokens
        record_out_of_band_usage(result) if usage_entries.length == entries_before
        record_generated_message(result, usage_start, announce: !announced, resumed:)
        record_completion_event(event, result)
      ensure
        event[:response_tokens] ||= Tokens.aggregate(usage_entries[entries_before..].map(&:tokens))
      end
      result
    end

    # Keeps the text a cancelled stream showed, as a reply marked
    # cancelled. Tool calls it had not finished and its thinking, whose
    # signature would not verify, are left out.
    def keep_cancelled_reply(text, usage_start)
      return if text.nil? || text.strip.empty?

      reply = Message.new(role: :assistant, content: text, model: @model.id, finish_reason: :cancelled)
      link_completion_usage(reply, usage_start)
      note_fallback(reply)
      add_message(reply)
      run_callbacks(:after_message, reply)
    end

    def record_generated_message(result, usage_start, announce: true, resumed: nil, keep_unfinished: false)
      raise_if_cancelled!
      link_completion_usage(result, usage_start, resumed)
      note_fallback(result)
      run_callbacks(:before_message) if announce
      keep_unfinished ? add_message(result) : replace_unfinished(result)
      run_callbacks(:after_message, result)
    end

    # An unfinished response stands in the transcript while it continues,
    # so a later #complete resumes it when the run stops early.
    def record_progress(partial)
      replace_unfinished(partial)
      raise_if_cancelled!
      @run.record_progress(partial)
    end

    def note_fallback(message)
      message.stood_in(model: @model.id, provider: @provider.slug) if @answering_fallback
    end

    def replace_unfinished(message)
      messages.pop if unfinished?(messages.last)
      add_message(message)
    end

    def unfinished?(message)
      message&.role == :assistant && !message.continuation.nil?
    end

    def instrumentation_payload(streaming:)
      empty_tokens = Tokens.new
      {
        chat: self,
        provider: @provider.slug,
        provider_class: @provider.name,
        model: @model.id,
        model_info: @model,
        input_messages: messages.dup,
        message_count: messages.size,
        tools: tools.keys,
        provider_tools: provider_tools,
        tool_choice: tool_prefs[:choice],
        tool_call_limit: tool_prefs[:calls],
        temperature: @temperature,
        max_output_tokens: @max_output_tokens,
        provider_options: provider_options,
        schema: schema,
        thinking: resolved_thinking,
        citations: @citations,
        caching: @caching,
        streaming: streaming,
        tokens: empty_tokens,
        cost: Cost.new(tokens: empty_tokens, model: @model),
        **agent_fields
      }
    end

    def record_completion_event(event, result)
      event[:response] = result
      event[:messages_after] = messages.dup
      event[:response_role] = result.role if result.respond_to?(:role)
      event[:tokens] = result.tokens
      event[:cost] = result.cost
      return unless result.respond_to?(:tool_call?)

      event[:response_model] = result.model
      event[:tool_call] = result.tool_call?
      event[:tool_calls] = result.tool_calls
    end

    def generate_with_fallbacks(&block)
      fallback_queue = fallbacks.dup
      attempt = 0
      active_fallback = nil
      streaming = block_given?
      usage_start = usage_entries.length
      block_failed = false
      on_chunk = block && proc do |chunk|
        block.call(chunk)
      rescue StandardError
        block_failed = true
        raise
      end

      drops = []
      loop do
        chunks_yielded = false

        begin
          result = generate_once(stream_tracker: proc { chunks_yielded = true }, usage_start:, &on_chunk)
          finish_fallback(active_fallback, response: result)
          return result
        rescue StandardError => e
          finish_fallback(active_fallback, fallback_error: e)
          raise e if block_failed || unfinished?(messages.last)

          active_fallback, attempt = next_attempt!(fallback_queue, drops, error: e, attempt:, streaming:,
                                                                          chunks_yielded:)
        end
      end
    ensure
      @answering_fallback = false
      restore_parameters(drops)
    end

    # Retries the same model without each parameter it rejects, when the
    # chat opted in, then moves on to the next model with every parameter
    # back. Each parameter is dropped at most once per model.
    def next_attempt!(fallback_queue, drops, error:, **details)
      if (restore = drop_unsupported_parameter(error))
        drops << restore
        return retry_without_parameter!(error:, **details)
      end
      restore_parameters(drops)
      raise error unless fallback_error?(error)

      fallback_to_next_model!(fallback_queue, error:, **details)
    end

    DROPPED_VALUES = { temperature: nil, max_output_tokens: nil, thinking: nil, citations: false }.freeze
    private_constant :DROPPED_VALUES

    # Clears the setting +error+ names for one retry, and returns how to put
    # it back, or +nil+ when the chat did not opt in or never set it.
    def drop_unsupported_parameter(error)
      return unless @drop_unsupported && error.is_a?(UnsupportedParameterError)

      parameter = error.parameter
      return drop_provider_option(parameter) unless parameter.is_a?(Symbol)
      return unless DROPPED_VALUES.key?(parameter)

      name = :"@#{parameter}"
      original = instance_variable_get(name)
      return if original.nil? || original == false

      instance_variable_set(name, DROPPED_VALUES[parameter])
      -> { instance_variable_set(name, original) }
    end

    def drop_provider_option(parameter)
      key = @provider_options.keys.find { |candidate| candidate.to_s == parameter.to_s }
      return unless key

      original = @provider_options
      @provider_options = original.except(key)
      -> { @provider_options = original }
    end

    def restore_parameters(drops)
      drops.pop.call until drops.nil? || drops.empty?
    end

    def retry_without_parameter!(error:, attempt:, streaming:, chunks_yielded:)
      attempt += 1
      fallback = Fallback.new(model: @model).with_attempt(
        chat: self, error:, from: @model, to: @model, attempt:, streaming:, chunks_yielded:,
        dropped_parameter: error.parameter
      )
      run_callbacks(:before_fallback, fallback)
      [fallback, attempt]
    end

    def with_model_restored
      original_model = @model
      original_provider = @provider
      original_connection = @connection
      original_protocol = @protocol

      yield
    ensure
      @model = original_model
      @provider = original_provider
      @connection = original_connection
      @protocol = original_protocol
    end

    def switch_to_fallback_model(fallback)
      from_provider = @provider.slug
      if fallback.model
        with_resolved_model(fallback.model)
      else
        with_model(fallback.id, provider: fallback.provider, protocol: @protocol)
      end
      @protocol = nil unless @provider.slug == from_provider
      self
    end

    def with_resolved_model(model)
      @provider = Provider.resolve!(model.provider).new(@config)
      @model = model
      @connection = @provider.connection
      self
    end

    def fallback_to_next_model!(fallback_queue, error:, attempt:, streaming:, chunks_yielded:)
      from_model = @model
      fallback = switch_to_usable_fallback(fallback_queue)
      raise error unless fallback

      @answering_fallback = true
      attempt += 1
      fallback = fallback.with_attempt(
        chat: self,
        error: error,
        from: from_model,
        to: @model,
        attempt: attempt,
        streaming: streaming,
        chunks_yielded: chunks_yielded
      )
      run_callbacks(:before_fallback, fallback)
      [fallback, attempt]
    end

    def switch_to_usable_fallback(fallback_queue)
      Fallback.next_usable(fallback_queue) { |fallback| switch_to_fallback_model(fallback) }&.first
    end

    def finish_fallback(fallback, response: nil, fallback_error: nil)
      return unless fallback

      fallback.finish(response: response, fallback_error: fallback_error)
      run_callbacks(:after_fallback, fallback)
    end

    def fallback_error?(error)
      !@run.interrupted_by?(error) && Fallback.error?(error, fallback_errors)
    end

    # Preprocessing builds a per-request view of the conversation: the
    # provider can change through fallbacks or with_model, so history keeps
    # the original attachments while each provider's upload is memoized on
    # them. An attachment's store keeps its uploads for later processes.
    def preprocessed_messages(list = messages)
      list = request_history(list)
      list = @file_references.view(list) if @file_references
      list = context_budget_for_model.fit(list) if @context_budget
      list = CodeExecution.for_model(with_skill_listing(list))
      return list unless @provider

      @provider.preprocess_messages(list, model: @model, protocol: @protocol,
                                          unsupported_attachment: unsupported_attachment_handler)
    end

    def context_budget_for_model
      ContextBudget.new(@context_budget, @model&.context_window).tap do |budget|
        warn_about_unknown_window unless budget.window? || @context_budget_warned
      end
    end

    def warn_about_unknown_window
      @context_budget_warned = true
      RubyLLM.logger.warn("RubyLLM has no context window for #{@model&.id}, so this chat's context budget does " \
                          'nothing. Pass window: to with_context_budget.')
    end

    def with_skill_listing(list)
      return list if skills.empty?

      index = list.index { |message| message.role != :system } || list.size
      list.dup.insert(index, Message.new(role: :system, content: @skill_loader.listing))
    end

    def with_mcp_outages(list)
      unreachable = mcp.unreachable
      return list if unreachable.empty?

      note = "These MCP servers can't be reached right now, so their tools are unavailable: " \
             "#{unreachable.join(', ')}. If a request needs them, say so."
      index = list.index { |message| message.role != :system } || list.size
      list.dup.insert(index, Message.new(role: :system, content: note))
    end

    def unsupported_attachment_handler
      callbacks = @callbacks[:unsupported_attachment]
      callbacks += [->(attachment) { @file_references.describe(attachment, config: @config) }] if @file_references
      return if callbacks.empty? && !@code_execution

      describe = attachment_describer
      lambda do |attachment|
        @attachment_replacements[attachment] ||= callbacks.lazy.filter_map { |handler| handler.call(attachment) }.first
        @attachment_replacements[attachment] || describe.call(attachment)
      end
    end

    # A run's names shift as files arrive, so descriptions are not memoized.
    def attachment_describer
      return ->(_attachment) {} unless @code_execution

      CodeExecution.describer(messages.flat_map(&:attachments))
    end

    # A process that dies mid-round leaves a blank assistant placeholder,
    # or tool calls without results, and providers refuse both. A request
    # leaves blank messages out and answers the calls of a round the
    # conversation moved past as unfinished. The latest round stays as it
    # is: the loop runs its calls or waits on them.
    def request_history(list)
      kept = list.reject { |message| blank_response?(message) }
      answered = kept.filter_map { |message| message.tool_call_id if message.tool_result? }
      current = latest_response(kept)
      kept.slice_before { |message| !message.tool_result? }.flat_map do |response, *results|
        abandoned = response.tool_call? && !response.equal?(current)
        [response, *results, *(abandoned ? unfinished_results(response, answered) : [])]
      end
    end

    def unfinished_results(response, answered)
      response.tool_calls.reject { |tool_call| answered.include?(tool_call.id) }
              .map { |tool_call| unfinished_result(tool_call) }
    end

    def unfinished_result(tool_call)
      (remote_refusal(tool_call) if tool_call.remote?) ||
        Message.new(role: :tool, content: UNFINISHED_TOOL_RESULT, tool_call_id: tool_call.id,
                    provider_call_id: tool_call.provider_call_id)
    end

    # A provider-executed call is closed with the refusal its provider
    # expects. Another provider takes it as an ordinary tool call.
    def remote_refusal(tool_call)
      @provider.tool_approval_response(tool_call, approved: false, model: @model, protocol: @protocol)
    rescue Error
      nil
    end

    def provider_completion(usage_recorder:, progress_recorder: nil, stream_tracker: nil, &)
      raise_if_cancelled!
      check_tool_choice(@tool_prefs[:choice]) unless mcp.empty?

      request_messages = with_mcp_outages(preprocessed_messages)
      tool_call_ids = ToolCallIds.new
      streamed = false
      tracker = proc do |chunk|
        streamed = true
        stream_tracker&.call(chunk)
      end
      on_chunk = wrap_streaming_block(tool_call_ids:, stream_tracker: tracker, &)

      sent = request_messages
      response = replacing_missing_uploads(request_messages, -> { streamed }) do |sent_messages|
        sent = sent_messages
        cancellable_request do
          @provider.complete(
            sent_messages,
            tools: request_tools,
            provider_tools: @provider_tools,
            tool_prefs: @tool_prefs,
            temperature: @temperature,
            max_output_tokens: @max_output_tokens,
            model: @model,
            provider_options: Support::Utils.deep_dup(@provider_options),
            headers: @headers,
            schema: @schema,
            thinking: resolved_thinking,
            citations: @citations,
            caching: request_caching,
            compaction: @compaction,
            end_user: @end_user,
            protocol: @protocol,
            before_request: @callbacks[:before_request],
            usage_recorder: usage_recorder,
            progress_recorder: progress_recorder,
            &on_chunk
          )
        end
      end
      @file_references&.record_shown(sent)
      tool_call_ids.assign(response)
    end

    def provider_compaction
      replacing_missing_uploads(preprocessed_messages) do |sent_messages|
        cancellable_request do
          @provider.compact(
            sent_messages, model: @model, protocol: @protocol,
                           headers: @headers, before_request: @callbacks[:before_request],
                           usage_recorder: method(:record_usage_entry)
          )
        end
      end
    end

    # A provider can delete a file RubyLLM uploaded for an attachment. A
    # request that fails over such a file before streaming anything uploads
    # the file again and runs once more; one that streamed is not repeated.
    def replacing_missing_uploads(request_messages, streamed = -> { false })
      yield request_messages
    rescue Error => e
      raise if streamed.call || discard_missing_uploads(e).empty?

      yield preprocessed_messages
    end

    def discard_missing_uploads(error)
      upload_messages = messages.map do |message|
        replacements = message.attachments.filter_map { |attachment| @attachment_replacements[attachment] }
        message.with_attachments(message.attachments + replacements)
      end
      @provider.discard_missing_uploads(upload_messages, error, model: @model, protocol: @protocol)
    end

    def record_usage_entry(entry)
      usage_entries << entry
      @run.record_usage(entry)
      entry
    end

    def link_completion_usage(response, usage_start, resumed = nil)
      earlier = resumed ? resumed.ruby_llm_usage_entries : []
      response.ruby_llm_usage_entries = earlier + usage_entries.drop(usage_start)
    end

    def record_out_of_band_usage(response)
      entry = Accounting::Usage::Entry.new(
        operation: :chat,
        provider: @provider.slug,
        model: response.model || @model.id,
        status: :succeeded,
        tokens: response.tokens,
        cost: response.cost,
        message: response,
        owner: Accounting::Usage.owner,
        workflow: Accounting::Usage.workflow
      )
      response.ruby_llm_usage_entries = [entry]
      Accounting::Usage.instrument(entry, config: @config)
      record_usage_entry(entry)
    end

    def run_callbacks(name, *args)
      @callbacks[name].each { |callback| callback.call(*args) }
    end

    def wrap_streaming_block(tool_call_ids:, stream_tracker: nil, &block)
      return nil unless block

      run_callbacks(:before_message)
      index = -1

      proc do |chunk|
        raise_if_cancelled!
        chunk = tool_call_ids.assign(chunk)
        chunk.index = index += 1
        stream_tracker&.call(chunk)
        block.call(chunk)
        raise_if_cancelled!
      end
    end

    def execute_pending_tool_calls(response)
      raise_if_cancelled!

      server_calls, local_calls = pending_tool_calls(response).to_h.partition { |_, call| call.remote? }.map(&:to_h)
      decisions = server_calls.transform_values { |tool_call| approval_decision(nil, tool_call) }.compact
      executable, denied = partition_pending_tool_calls(local_calls)
      executable = executable.reject { |_id, tool_call| exclusive_blocked?(tool_call, executable) }
      claimed = claim_tool_calls(executable, server_calls.slice(*decisions.keys).merge(denied))
      answer_claimed_tool_calls(claimed, server_calls, decisions, executable, denied)
      @tool_prefs[:choice] = nil if forced_tool_choice?
    end

    def answer_claimed_tool_calls(claimed, server_calls, decisions, executable, denied)
      respond_to_tool_approvals(server_calls.slice(*claimed), decisions)
      deny_tool_calls(denied.slice(*claimed))
      if concurrency && executable.values.none? { |tool_call| ordered?(tool_call) }
        handle_concurrent_tool_calls(executable.slice(*claimed))
      else
        handle_sequential_tool_calls(executable.slice(*claimed))
      end
    ensure
      release_tool_calls(claimed)
    end

    def claim_tool_calls(executable, answered)
      requested = executable.keys + answered.keys
      @tool_call_state.claim(requested, executing: executable.keys) do
        leases = executable.values.to_h { |tool_call| [tool_call, max_run_time_for(tool_call)] }
        answered.each_value { |tool_call| leases[tool_call] = @config.max_run_time }
        leases
      end
    end

    def release_tool_calls(ids)
      answered = messages.filter_map { |message| message.tool_call_id if message.tool_result? }
      @tool_call_state.release(ids - answered)
    end

    def max_run_time_for(tool_call)
      tool_for(tool_call)&.max_run_time || @config.max_run_time
    end

    def running_elsewhere?(tool_call)
      @tool_call_state.running_elsewhere?(tool_call)
    end

    def respond_to_tool_approvals(tool_calls, decisions)
      tool_calls.each do |id, tool_call|
        decision = decisions.fetch(id)
        raise_if_cancelled!
        run_callbacks(:before_message)
        note = note_text(decline_note(tool_call)) unless decision
        response = @provider.tool_approval_response(tool_call, approved: decision, model: @model, protocol: @protocol,
                                                               note:)
        message = add_message(response)
        run_callbacks(:after_message, message)
      end
    end

    def partition_pending_tool_calls(pending)
      partition_tool_sequences(pending)
    end

    def execution_decision(tool_call)
      return false if tool_call.malformed_arguments?

      tool = tool_for(tool_call)
      return approval_decision(tool, tool_call) if tool&.requires_approval?(tool_call)

      !@tool_call_state.denied?(tool_call)
    end

    def deny_tool_calls(tool_calls)
      tool_calls.each_value do |tool_call|
        raise_if_cancelled!
        run_callbacks(:before_message)
        add_tool_result_message(tool_call, refusal(tool_call))
      end
    end

    def refusal(tool_call)
      note = decline_note(tool_call) unless tool_call.malformed_arguments?
      note.is_a?(Hash) ? note : { error: refusal_error(tool_call, note) }
    end

    def refusal_error(tool_call, note)
      name = tool_call.name
      return note || "The user denied the #{name} tool call." unless tool_call.malformed_arguments?

      "The arguments for #{name} were #{tool_call.malformed_arguments_problem}. Call #{name} again with a JSON object."
    end

    def record_tool_call_decision(tool_call, decision)
      id = tool_call.respond_to?(:id) ? tool_call.id : tool_call
      @tool_call_state.record_decision(id, decision)
      self
    end

    def approval_decision(tool, tool_call)
      return false if tool_call.malformed_arguments?

      decision = tool_call_approval(tool, tool_call)
      return decision unless decision.nil?
      return if tool.is_a?(CodeExecution)

      true if remembered_tool?(tool_call)
    end

    def remembered_tool?(call)
      @tool_call_state.remembered?(call)
    end

    def remembered_tool_identity(tool_call)
      id = tool_call.respond_to?(:id) ? tool_call.id : tool_call
      call = tool_call.respond_to?(:name) ? tool_call : find_tool_call(id)
      raise ArgumentError, "Unknown tool call: #{id.inspect}" unless call
      if call.name == CodeExecution.tool_name && call.namespace.nil?
        raise ArgumentError, "#{call.name} calls are approved one at a time and cannot be remembered"
      end

      [call.namespace, call.name.to_s]
    end

    def tool_call_answered?(tool_call)
      id = tool_call.respond_to?(:id) ? tool_call.id : tool_call
      messages.any? { |message| message.tool_result? && message.tool_call_id == id }
    end

    def find_tool_call(id)
      messages.reverse_each do |message|
        call = message.tool_calls[id]
        return call if call
      end
      nil
    end

    def reused_tool_call_id?(id)
      id.nil? || find_tool_call(id) || (block_given? && yield(id))
    end

    def escalation_approved?(tool_call)
      return false if tool_call.nil? || @tool_call_state.escalation_spent?(tool_call)

      @tool_call_state.spend_escalation(tool_call)
      tool_call_approval(nil, tool_call) == true
    end

    def tool_call_approval(tool, tool_call)
      return tool.approval_resolver.call(tool_call) if tool&.approval_resolver

      @tool_call_state.decision(tool_call)
    end

    def handle_sequential_tool_calls(tool_calls)
      tool_calls.each_value do |tool_call|
        next if sequence_blocked?(tool_call) || exclusive_blocked?(tool_call)

        raise_if_cancelled!
        result = skipped_result(tool_call) || execute_tool_with_callbacks(tool_call)
        next if result.equal?(PAUSED)

        run_callbacks(:before_message)
        add_tool_result_message(tool_call, result)
      end
    end

    def handle_concurrent_tool_calls(tool_calls)
      execute_tools_concurrently(tool_calls) do |tool_call, result|
        next if result.equal?(PAUSED)

        run_callbacks(:before_message)
        add_tool_result_message(tool_call, result)
      end
    end

    def execute_tools_concurrently(tool_calls, &on_result)
      exclusive = ->(tool_call) { exclusive_call?(tool_call) }
      paused = ->(result) { result.equal?(PAUSED) }
      ToolConcurrency.run(concurrency, tool_calls, exclusive:, paused:, on_result:, config: @config) do |tool_call|
        execute_tool_with_callbacks(tool_call)
      end
    end

    def execute_tool_with_callbacks(tool_call)
      raise_if_cancelled!
      @tool_call_state.started(tool_call)
      run_callbacks(:before_tool_call, tool_call)
      result = run_around_tool_call(tool_call) { execute_tool tool_call }
      return result if result.equal?(PAUSED)

      run_callbacks(:after_tool_result, result.is_a?(Tool::Halt) ? result.content : result)
      result
    end

    def run_around_tool_call(tool_call, &execute)
      ran = false
      result = nil
      innermost = lambda do
        result = execute.call unless ran
        ran = true
        result
      end
      outcome = -> { ran ? result : { error: "The #{tool_call.name} call did not run." } }
      chain = @callbacks[:around_tool_call].reverse.reduce(innermost) do |inner, callback|
        lambda do
          callback.call(tool_call) { inner.call }
          outcome.call
        end
      end
      chain.call
      outcome.call
    end

    def add_tool_result_message(tool_call, result)
      halted = result.is_a?(Tool::Halt)
      result = result.content if halted
      content, attachments = split_tool_result(result)
      content = @file_references.spill(tool_for(tool_call), tool_call, content) if @file_references
      content = context_budget_for_model.cap(content) if @context_budget
      mcp_result = result if result.is_a?(MCP::Result) && result.ui_uri
      message = add_message(role: :tool, content:, attachments:, tool_call_id: tool_call.id,
                            provider_call_id: tool_call.provider_call_id, mcp_result:,
                            finish_reason: (:halted if halted))
      run_callbacks(:after_message, message)
      message
    end

    # The tool has run, so a result that cannot be sent goes back as an
    # error: raising would leave the call pending and run it again.
    def split_tool_result(result)
      Tool.split_result(result)
    rescue StandardError => e
      Tool.split_result({ error: e.message })
    end

    def execute_tool(tool_call)
      tool = tool_for(tool_call)
      return { error: unavailable_tool_error(tool_call.qualified_name) } if tool.nil?

      args = tool_call.arguments
      payload = {
        chat: self,
        provider: @provider.slug,
        provider_class: @provider.name,
        model: @model.id,
        model_info: @model,
        tool: tool,
        tool_call: tool_call,
        tool_name: tool.name,
        tool_arguments: args,
        tool_call_id: tool_call.id,
        **agent_fields
      }

      RubyLLM.instrument('tool_call.ruby_llm', payload, config: @config) do |event|
        result = Support::Cancellation.watch(-> { raise_if_cancelled! }) do
          Support::ProgressReporter.listen(progress_listener(tool_call)) { invoke_tool(tool, tool_call, args) }
        end
        event[:result] = result
        event[:result_content] = result
        event[:result_class] = result.class.name
        result
      end
    end

    # Names a few close tools rather than every tool, which can run to
    # thousands of characters in a chat with many.
    def unavailable_tool_error(name)
      close = DidYouMean::SpellChecker.new(dictionary: tools.keys.map(&:to_s)).correct(name).first(3)
      message = "There is no tool named `#{name}`."
      message += " Did you mean #{close.map { |tool| "`#{tool}`" }.join(', ')}?" if close.any?
      message += " Find tools with `#{Tools::Search.tool_name}`." if tool_search_tool
      message
    end

    def progress_listener(tool_call)
      return if @callbacks.fetch(:after_tool_progress, []).empty?

      ->(progress) { run_callbacks(:after_tool_progress, tool_call, progress) }
    end

    def invoke_tool(tool, tool_call, arguments)
      input = tool_call_input(tool_call)
      result = Tool.asking(tool, input) do
        rescuing_tool(tool) do
          input ? tool.resume_call(input, arguments, tool_call:) : tool.call(**arguments, tool_call:)
        end
      end
      return pause_tool_call(tool_call, result.to_h) if result.is_a?(Task)

      record_tool_call_input(tool_call, nil) if input
      with_decline_notes(result, input)
    rescue InputRequiredError => e
      pause_tool_call(tool_call, e.to_h)
    end

    # The one place a tool's Tool.rescue_from handlers run, so they cover
    # every call a chat makes, whether the tool overrides Tool#call or
    # Tool#execute. A question or a cancellation is how a call pauses or
    # stops, not a failure, so it never reaches a handler; a handler may
    # end the turn with Tool#halt.
    def rescuing_tool(tool)
      catch(Tool::HALT) do
        yield
      rescue InputRequiredError, CancelledError
        raise
      rescue StandardError => e
        tool.rescue_with_handler(e)
      end
    end

    def with_decline_notes(result, input)
      notes = Array(input&.[]('requests')).filter_map do |request|
        note = request.dig('response', 'note')
        "The user declined: #{note_text(note)}" if note
      end
      notes.empty? ? result : noted_result(result, notes)
    end

    def noted_result(result, notes)
      case result
      when Tool::Halt then Tool::Halt.new(noted_result(result.content, notes))
      when MCP::Result
        blocks = notes.map { |note| { 'type' => 'text', 'text' => note } }
        MCP::Result.new(result.to_h.merge('content' => [*result.to_h['content'], *blocks]), result.ui_uri)
      else
        content, attachments = split_tool_result(result)
        text = [content, *notes].reject(&:empty?).join("\n\n")
        attachments.empty? ? text : [text, *attachments]
      end
    end

    def pause_tool_call(tool_call, state)
      record_tool_call_input(tool_call, state)
      PAUSED
    end

    def paused?(tool_call)
      state = tool_call_input(tool_call)
      !state.nil? && (unanswered?(state) || state.key?('task'))
    end

    def input_pending?(tool_call)
      unanswered?(tool_call_input(tool_call))
    end

    def unanswered?(state)
      Array(state&.[]('requests')).any? { |request| request['response'].nil? }
    end

    def task_for(tool_call, state)
      tool = tool_for(tool_call)
      return tool.task(state, tool_call:) if tool
      return MCP::Task.load(nil, state, tool_call:) if state['task'].key?('taskId')

      Task.load(state, tool_call:)
    end

    def cancel_tasks
      response = pending_tool_response
      return unless response

      pending_tool_calls(response).each do |tool_call|
        state = tool_call_input(tool_call)
        next unless state&.key?('task')

        cancel_task(task_for(tool_call, state))
        record_tool_call_input(tool_call, nil)
      end
    end

    def close_unstarted_tool_calls
      response = pending_tool_response
      return unless response

      pending_tool_calls(response).each do |tool_call|
        next if running_elsewhere?(tool_call)

        record_tool_call_input(tool_call, nil) if tool_call_input(tool_call)
        run_callbacks(:before_message)
        run_callbacks(:after_message, add_message(unfinished_result(tool_call).mark_cancelled))
      end
    end

    def cancel_task(task)
      task.cancel
    rescue Error, ConfigurationError, Faraday::Error => e
      RubyLLM.logger.debug { "RubyLLM could not cancel the task of tool call #{task.tool_call&.id}: #{e.message}" }
    end

    def tool_call_input(tool_call)
      @tool_call_state.input(tool_call)
    end

    def record_tool_call_input(tool_call, input)
      @tool_call_state.record_input(tool_call, input)
    end

    def unanswered_questions(tool_call)
      Array(tool_call_input(tool_call)&.[]('requests')).filter_map do |data|
        Question.from_h(data, tool_call:, chat: self) unless data['response']
      end
    end

    def pending_question(question)
      id = question.respond_to?(:id) ? question.id : question.to_s
      pending_questions.find { |pending| pending.id == id } ||
        (asked_question?(id) ? nil : raise(ArgumentError, "Unknown question: #{id.inspect}"))
    end

    def asked_question?(id)
      [id, id.rpartition('/').first].any? { |tool_call_id| find_tool_call(tool_call_id) }
    end

    def record_answer(question, response)
      @tool_call_state.settle(question.tool_call) { |input| question.answered_input(input, response) }
    end

    # Records +response+ to +question+ and returns whether it did. An
    # approval is approved or denied only while no decision came first, so
    # of two people deciding at once, the first one's decision stands.
    def settle_question(question, response)
      unless question.approval?
        record_answer(question, response)
        return true
      end

      @tool_call_state.exclusively do
        next false unless approval_pending?(question.tool_call)

        response == Question::ACCEPTED ? approve(question) : refuse(question.tool_call, response['note'])
        true
      end
    end

    def refuse(tool_call, note)
      record_tool_call_decision(tool_call, false)
      @tool_call_state.record_decline_note(tool_call, note) if note
    end

    def decline_note(tool_call)
      @tool_call_state.decline_note(tool_call)
    end

    def note_text(note)
      note.is_a?(Hash) ? JSON.generate(note) : note
    end

    def apply_tool_choice(choice)
      if choice.nil?
        @tool_prefs[:choice] = nil
      else
        normalized_choice = normalize_tool_choice(choice)
        check_tool_choice(normalized_choice, choice) if mcp.empty?
        @tool_prefs[:choice] = normalized_choice
      end
    end

    # A chat with MCP servers checks its choice once it lists their tools,
    # so building it never contacts them.
    def check_tool_choice(choice, given = choice)
      return if choice.nil? || TOOL_CHOICE_MODES.include?(choice) || tools.key?(choice)

      message = "Invalid tool choice: #{given}. Valid choices are: #{(TOOL_CHOICE_MODES + tools.keys).join(', ')}"
      unreachable = mcp.unreachable
      message += ". These MCP servers can't be reached right now: #{unreachable.join(', ')}" if unreachable.any?
      raise InvalidToolChoiceError, message
    end

    def apply_tool_concurrency(value)
      @concurrency_chosen = !value.nil?
      @concurrency = normalize_tool_concurrency(value.nil? ? @config.tool_concurrency : value)
    end

    def normalize_tool_concurrency(concurrency)
      return nil if concurrency.nil? || concurrency == false
      return :threads if concurrency == true

      normalized = concurrency.to_sym
      return normalized if ToolConcurrency::MODES.include?(normalized)

      raise ArgumentError,
            "Unknown tool concurrency: #{concurrency.inspect}. " \
            "Available modes: #{ToolConcurrency::MODES.join(', ')}"
    end

    def normalize_calls(calls)
      case calls
      when :many, 'many'
        :many
      when :one, 'one', 1
        :one
      else
        raise ArgumentError, "Invalid calls value: #{calls.inspect}. Valid values are: :many, :one, or 1"
      end
    end

    def normalize_tool_choice(choice)
      return choice.to_sym if choice.is_a?(String) || choice.is_a?(Symbol)
      return tool_name_for_choice_class(choice) if choice.is_a?(Class)
      return choice.qualified_name.to_sym if choice.is_a?(Tool)

      choice.respond_to?(:name) ? choice.name.to_sym : choice.to_sym
    end

    def tool_name_for_choice_class(tool_class)
      matched_tool_name = @tools.find { |_name, tool| tool.is_a?(tool_class) }&.first
      return matched_tool_name if matched_tool_name
      return tool_class.name.to_s.to_sym unless tool_class.respond_to?(:tool_name)

      namespace = tool_class.namespace if tool_class.respond_to?(:namespace)
      [namespace, tool_class.tool_name].compact.join('_').to_sym
    end

    def forced_tool_choice?
      @tool_prefs[:choice] && !%i[auto none].include?(@tool_prefs[:choice])
    end

    def last_non_system_message
      messages.reverse.find { |message| message.role != :system }
    end

    def hidden_from_model?(tool)
      tool.is_a?(MCP::Tool) && !tool.visibility.include?(:model)
    end

    def pending_tool_response
      response = latest_response(messages)
      response if response&.tool_call? && pending_tool_calls(response).any?
    end

    # A blank response answers nothing, so it never hides the round before
    # it, as the placeholder of a process that died after a tool finished.
    def latest_response(list)
      list.reverse.find do |message|
        message.role != :system && !message.tool_result? && !blank_response?(message)
      end
    end

    # What a process leaves behind before the provider answers, unlike a
    # blank answer, which carries its finish reason or usage.
    def placeholder?(message)
      return false unless message && blank_response?(message) && !unfinished?(message)

      message.finish_reason.nil? && message.tokens.input.nil?
    end

    def blank_response?(message)
      message.role == :assistant && !message.tool_call? && message.content.to_s.strip.empty? &&
        message.attachments.empty? && message.thinking.nil? && message.server_tool_calls.empty? &&
        message.raw_content.nil? && message.raw_reasoning.nil?
    end

    def pending_tool_calls(response)
      answered = messages.filter_map { |message| message.tool_call_id if message.tool_result? }
      response.tool_calls.except(*answered)
    end

    def inspect_attributes # :nodoc:
      {
        model: model.id,
        provider: provider.slug,
        messages: messages.count,
        tools: tools.keys,
        awaiting_approval: awaiting_approval_names
      }
    end

    def awaiting_approval_names
      pending_questions.select(&:approval?).map { |question| question.tool_call.name }.uniq
    end
  end
end
