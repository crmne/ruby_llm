# frozen_string_literal: true

require 'delegate'
require 'schematist'

module RubyLLM
  class Parameter # :nodoc:
    attr_reader :name, :type, :description, :required

    def initialize(name, type: 'string', description: nil, required: true)
      @name = name
      @type = type
      @description = description
      @required = required
    end
  end

  # A Tool is an action an AI model can call during a chat. Subclasses
  # describe themselves with ::description, declare their arguments, and
  # implement #execute:
  #
  #   class Weather < RubyLLM::Tool
  #     description "Gets current weather for a location"
  #
  #     def execute(latitude:, longitude:)
  #       response = Faraday.get "https://api.open-meteo.com/v1/forecast",
  #                              latitude: latitude, longitude: longitude,
  #                              current: "temperature_2m,wind_speed_10m"
  #       JSON.parse(response.body)
  #     end
  #   end
  #
  #   chat.with_tools(Weather).ask "What's the weather in Berlin?"
  #
  # When no parameters are declared, the argument schema is inferred from
  # #execute's keyword arguments: required keywords become required string
  # parameters and optional keywords become optional ones. Use ::parameter
  # or ::parameters when arguments need explicit types, descriptions, or
  # structure.
  class Tool
    KEYWORD_PARAMETER_KINDS = %i[keyreq key].freeze # :nodoc:
    TOOL_CALL_KEYWORD = :tool_call # :nodoc:
    ASKING = :ruby_llm_tool_asking # :nodoc:
    RESUMING = :ruby_llm_tool_resuming # :nodoc:

    DUPED_INHERITED_CONFIG = {
      :@declared_parameters => {},
      :@provider_options => {}
    }.freeze
    COPIED_INHERITED_CONFIG = %i[
      @description
      @namespace
      @parameters_schema_definition
      @requires_approval
      @approval_resolver
      @deferred
      @max_run_time
      @spill_to_file
    ].freeze
    private_constant :DUPED_INHERITED_CONFIG, :COPIED_INHERITED_CONFIG

    class << self
      attr_reader :parameters_schema_definition, :approval_resolver # :nodoc:

      def inherited(subclass) # :nodoc:
        super
        DUPED_INHERITED_CONFIG.each do |ivar, default|
          value = instance_variable_defined?(ivar) ? instance_variable_get(ivar) : default
          subclass.instance_variable_set(ivar, value.dup)
        end

        COPIED_INHERITED_CONFIG.each do |ivar|
          subclass.instance_variable_set(ivar, instance_variable_get(ivar))
        end
      end

      # Returns the name the model calls this tool by, derived from the class
      # name: underscored, reduced to ASCII, with a trailing "_tool" removed.
      # Override this method to choose a different name.
      #
      #   WeatherLookup.tool_name  # => "weather_lookup"
      #
      def tool_name
        return @tool_name if @tool_name

        normalized = name.to_s.dup.force_encoding('UTF-8').unicode_normalize(:nfkd)
        ascii_name = normalized.encode('ASCII', replace: '').gsub(/[^a-zA-Z0-9_-]/, '-')
        derived = Support::Utils.underscore(ascii_name).delete_suffix('_tool')
        @tool_name = derived if name
        derived
      end

      # :call-seq:
      #   description(text) -> text
      #   description -> string or nil
      #
      # Sets the description the model sees for this tool, or returns the
      # current description when called without an argument.
      #
      #   class Weather < RubyLLM::Tool
      #     description "Gets current weather for a location"
      #   end
      #
      def description(text = nil)
        return @description unless text

        @description = text
      end

      # Sets the namespace that owns this tool, or returns its current
      # namespace. Pass +nil+ to remove an inherited namespace.
      #
      #   class Screenshot < RubyLLM::Tool
      #     namespace "computer"
      #   end
      def namespace(value = (get = true))
        return @namespace if get

        @namespace = value&.to_s
      end

      # Declares a parameter for the tool. +options+ accepts +type:+
      # (defaults to <tt>'string'</tt>), +description:+, and +required:+
      # (defaults to +true+).
      #
      #   class Distance < RubyLLM::Tool
      #     description "Calculates distance between two cities"
      #     parameter :origin, description: "Origin city name"
      #     parameter :destination, description: "Destination city name"
      #     parameter :units, type: :string, description: "metric or imperial", required: false
      #   end
      #
      def parameter(name, **)
        declared_parameters[name] = Parameter.new(name, **)
      end

      def declared_parameters # :nodoc:
        @declared_parameters ||= {}
      end

      # Sets the JSON Schema for the tool's arguments. Accepts a schema hash,
      # a Schematist::Schema class or instance, or a block written in the
      # schematist DSL. Returns +self+.
      #
      #   class Scheduler < RubyLLM::Tool
      #     description "Books a meeting"
      #
      #     parameters do
      #       object :window, description: "Time window to reserve" do
      #         string :start, description: "ISO8601 start time"
      #         string :finish, description: "ISO8601 end time"
      #       end
      #       array :participants, of: :string
      #     end
      #   end
      #
      # Raises ArgumentError when called without a schema or a block.
      def parameters(schema = nil, &block)
        if schema.nil? && block.nil?
          raise ArgumentError, 'parameters requires a schema or a block; declare single arguments with parameter'
        end

        @parameters_schema_definition = SchemaDefinition.new(schema:, block:)
        self
      end

      # Declares that this tool must be approved before it executes. The
      # conversation loop pauses the tool call until a decision is recorded with
      # Chat#approve or Chat#deny, so Chat#complete returns cleanly and
      # can be called again once the decision exists. In Rails the decision
      # persists on the tool call record and survives process restarts.
      #
      #   class IssueRefund < RubyLLM::Tool
      #     requires_approval
      #
      #     def execute(order_id:)
      #       Refunds.issue!(order_id)
      #     end
      #   end
      #
      # Pass a block to resolve the decision yourself instead of using the
      # recorded one. The block receives the ToolCall and returns +true+ to
      # execute, +false+ to deny, or +nil+ while the decision is pending.
      #
      # The block never runs at class definition. The loop consults it
      # whenever it needs the decision, which can be several times while
      # the call is pending, including after a crashed job resumes, so
      # write it as an idempotent read. If it also creates the approval
      # request, make that a find-or-create.
      #
      #   requires_approval { |tool_call| Approvals.status(tool_call.id) }
      #
      def requires_approval(&resolver)
        @requires_approval = true
        @approval_resolver = resolver
      end

      def requires_approval? # :nodoc:
        @requires_approval || false
      end

      # :call-seq:
      #   max_run_time(seconds) -> seconds
      #   max_run_time -> seconds or nil
      #
      # Sets how long a run of this tool may take before a persisted chat
      # treats it as crashed, overriding Configuration#max_run_time. Another
      # process that resumes the chat after that time runs the call again.
      # Without an argument, returns the declared value, or +nil+.
      #
      #   class GenerateReport < RubyLLM::Tool
      #     max_run_time 2.hours
      #   end
      #
      def max_run_time(seconds = nil)
        @max_run_time = seconds if seconds
        @max_run_time
      end

      # :call-seq:
      #   provider_options(options) -> self
      #   provider_options -> hash
      #
      # Sets provider-specific metadata, such as Anthropic's +cache_control+
      # hints, merged verbatim into the tool payload sent to the provider.
      # Without an argument, returns the current options.
      #
      #   provider_options cache_control: { type: "ephemeral" }
      #
      # Raises ArgumentError if +options+ is +nil+.
      def provider_options(options = (get = true))
        return @provider_options ||= {} if get
        raise ArgumentError, 'provider_options does not accept nil' if options.nil?

        @provider_options = options.to_h
        self
      end

      # Keeps this tool's definition out of the model's context until the
      # provider's tool search loads it. Pass +defer: false+ to
      # Chat#with_tools to offer it up front in one chat. See
      # Chat#deferred_tools.
      #
      #   class DeepResearch < RubyLLM::Tool
      #     description "Runs a multi-step web investigation"
      #     defer
      #   end
      #
      def defer
        @deferred = true
      end

      def deferred? # :nodoc:
        @deferred || false
      end

      # :call-seq:
      #   spill_to_file(characters) -> characters
      #   spill_to_file(false) -> false
      #   spill_to_file -> characters, false, or nil
      #
      # Sets how many characters this tool's results may have before a
      # chat with files saves them as a file and sends the model their
      # start and the file's path, overriding the chat's own limit (see
      # Chat#with_file_store). +false+ always sends them whole, for tools that
      # already return what they find in pages. Without an argument,
      # returns the declared value, or +nil+.
      #
      #   class ExportOrders < RubyLLM::Tool
      #     spill_to_file 50_000
      #   end
      #
      def spill_to_file(characters = (get = true))
        return @spill_to_file if get
        unless characters == false || (characters.is_a?(Integer) && characters.positive?)
          raise ArgumentError, 'spill_to_file takes a positive number of characters or false'
        end

        @spill_to_file = characters
      end

      def split_result(result) # :nodoc:
        case result
        when Attachment then ['', [result]]
        when Array then split_array_result(result)
        when MCP::Result then split_result(result.content)
        else [result_content(result), []]
        end
      end

      private

      def split_array_result(result)
        parts = result.flatten.compact
        return [result_content(result), []] if parts.none?(Attachment)

        texts, attachments = parts.partition { |part| part.is_a?(String) }
        unless attachments.all?(Attachment)
          raise ArgumentError, 'Tool results mixing attachments can only contain Strings and RubyLLM::Attachments'
        end

        [texts.join("\n\n"), attachments]
      end

      def result_content(result)
        case result
        when String then result
        when Hash, Array, SearchResults then result.to_json
        else result.to_s
        end
      end
    end

    # Returns the name the model calls this tool by, delegating to
    # ::tool_name. Override either one to choose a different name.
    #
    #   WeatherLookup.new.name  # => "weather_lookup"
    #
    def name
      self.class.tool_name
    end

    # Returns the namespace that owns this tool, or +nil+ for an ordinary
    # function tool. See ::namespace.
    def namespace
      self.class.namespace
    end

    def qualified_name # :nodoc:
      namespace ? "#{namespace}.#{name}" : name
    end

    # Returns the tool description declared on the class with ::description.
    def description
      self.class.description
    end

    # Returns whether +tool_call+ must be approved before it runs: whether
    # this tool was declared with ::requires_approval. A subclass may
    # override it to decide from the call's arguments.
    def requires_approval?(tool_call = nil) # rubocop:disable Lint/UnusedMethodArgument
      self.class.requires_approval?
    end

    def approval_resolver # :nodoc:
      self.class.approval_resolver
    end

    # Returns the limit declared on the class with ::spill_to_file: a number
    # of characters, +false+, or +nil+ to use the chat's.
    def spill_to_file
      self.class.spill_to_file
    end

    # Returns the run time declared on the class with ::max_run_time, or
    # +nil+ to use Configuration#max_run_time.
    def max_run_time
      self.class.max_run_time
    end

    def declared_parameters # :nodoc:
      self.class.declared_parameters
    end

    # Returns the provider-specific tool metadata declared on the class.
    def provider_options
      self.class.provider_options
    end

    # Keeps this tool, and no other of its class, out of the model's
    # context until tool search loads it, as ::defer does for the class.
    # Returns +self+. Chat#with_tools and Chat#with_mcp take +defer:+ to
    # decide for every tool they register instead.
    #
    #   chat.with_tools(CurrentTime.new, *connector_tools.map(&:defer))
    #
    def defer
      @deferred = true
      self
    end

    # Returns whether this tool waits to be found by tool search: whether
    # it was deferred with #defer, or its class with ::defer.
    def deferred?
      @deferred || self.class.deferred?
    end

    class Deferred < SimpleDelegator # :nodoc:
    end

    # Returns the JSON Schema for the tool's arguments, whether declared
    # explicitly or inferred from the +execute+ signature.
    def parameters_schema
      return @parameters_schema if defined?(@parameters_schema)

      @parameters_schema = begin
        definition = self.class.parameters_schema_definition
        if definition&.present?
          definition.json_schema
        elsif declared_parameters.any?
          SchemaDefinition.from_parameters(declared_parameters)&.json_schema
        else
          SchemaDefinition.from_parameters(inferred_parameters, allow_empty: true)&.json_schema
        end
      end
    end

    # Runs the tool with keyword arguments, validating them against the
    # #execute signature before invoking it. RubyLLM supplies +tool_call:+
    # when the call comes from a chat; pass it yourself only when you need
    # the ToolCall in a direct invocation.
    #
    #   Weather.new.call(latitude: 52.52, longitude: 13.405)
    #
    def call(tool_call: nil, **arguments)
      normalized_args = arguments.transform_keys(&:to_sym)
      validation_error = validate_keyword_arguments(normalized_args)
      return { error: "Invalid tool arguments: #{validation_error}" } if validation_error

      RubyLLM.logger.debug { "Tool #{name} called with: #{normalized_args.inspect}" }
      normalized_args[TOOL_CALL_KEYWORD] = tool_call if execute_accepts_tool_call?
      result = asking { execute(**normalized_args) }
      RubyLLM.logger.debug { "Tool #{name} returned: #{result.inspect}" }
      result
    end

    # Asks the user something while #execute runs, and returns their
    # InputRequest::Answer. In a chat, the call pauses until Chat#answer or
    # Chat#decline settles the question (see Chat#pending_inputs), then runs
    # again from the start, and this +ask+ returns the answer. Code before
    # it runs again too, so do work after asking. Pass the fields to ask for
    # as JSON Schema properties, with <tt>required: true</tt> on the ones
    # the user must fill, or +url:+ to ask them to visit a page.
    #
    #   def execute(question:)
    #     answer = ask(question, answer: { type: "string", title: "Answer" })
    #     answer.accepted? ? { answer: answer[:answer] } : { error: "Nobody answered." }
    #   end
    #
    # Each call may ask several questions, one after another. Outside a chat,
    # an unanswered question raises InputRequiredError. +url:+ is reserved
    # for the page, so name a form field for a URL something else.
    def ask(message, url: nil, **fields)
      raise ArgumentError, 'url: takes the page to visit; give a form field another name' if url.is_a?(Hash)

      state = (Fiber[ASKING] ||= { 'input' => nil, 'asked' => 0 })
      index = state['asked']
      state['asked'] += 1
      requests = Array(state['input']&.[]('requests'))

      if (data = requests[index]) && data['response']
        InputRequest::Answer.new(data['response'])
      else
        asked = requests.first(index).map { |data| InputRequest.from_h(data) }
        asked << InputRequest.ask(index, message, url:, fields:)
        raise InputRequiredError.new(name, { 'requests' => asked })
      end
    end

    # Runs the tool with the arguments chosen by the model. Subclasses must
    # implement this method; the base implementation raises
    # NotImplementedError. The return value is sent back to the model.
    # Return a Hash like <tt>{ error: "..." }</tt> to report a recoverable
    # failure.
    #
    # Declare an optional +tool_call:+ keyword to receive the ToolCall being
    # executed. The keyword is reserved: it never appears in the tool's
    # argument schema and is filled in by RubyLLM, not by the model.
    #
    #   def execute(query:, tool_call: nil)
    #     AuditLog.create!(tool_call_id: tool_call&.id)
    #     Search.run(query)
    #   end
    #
    def execute(...)
      raise NotImplementedError, 'Subclasses must implement #execute'
    end

    # Carries on a call that paused on +task+, the Task #execute returned,
    # with the call's +arguments+. Each Chat#complete calls it once for
    # every paused call of the round. Return the call's result to finish
    # it, or a Task, +task+ itself or a new one, to keep it paused. Tools
    # that return a Task must implement this method; the base
    # implementation raises NotImplementedError.
    #
    #   def resume(task, **)
    #     run = SubAgentRun.find(task.data["run_id"]).continue
    #     run.finished? ? run.answer : task
    #   end
    #
    def resume(task, **arguments)
      raise NotImplementedError, "#{self.class} returned a Task, so it must implement #resume"
    end

    # Returns the Task that +tool_call+ paused on, from +state+, the Hash
    # Task#to_h returned. Override it to return a Task subclass.
    #
    #   def task(state, tool_call: nil)
    #     SubAgentTask.load(state, tool_call:)
    #   end
    #
    def task(state, tool_call: nil)
      Task.load(state, tool_call:)
    end

    def resume_call(state, arguments, tool_call:) # :nodoc:
      return answered(state, arguments, tool_call:) unless state.key?('task')

      resume(task(state, tool_call:), **arguments.transform_keys(&:to_sym))
    end

    # Reports what the tool is doing while #execute runs, so an application
    # can show it before the result arrives. Chat#after_tool_progress
    # callbacks receive it as a Progress. Pass +value:+ and +total:+ when
    # you can count the work. Outside a chat, the report goes nowhere.
    #
    #   def execute(url:)
    #     progress "Downloading #{File.basename(url)}"
    #     pages = Scanner.pages(url)
    #     pages.each_with_index.map do |page, index|
    #       progress "Reading page #{index + 1} of #{pages.size}", value: index + 1, total: pages.size
    #       page.text
    #     end.join("\n")
    #   end
    #
    def progress(message = nil, value: nil, total: nil)
      Support::ProgressReporter.report(Progress.new(value:, total:, message:))
      nil
    end

    protected

    def validate_keyword_arguments(arguments) # :nodoc:
      required_keywords, optional_keywords, accepts_extra_keywords = execute_keyword_signature

      argument_keys = arguments.keys
      missing_keyword = (required_keywords - argument_keys).first
      return "missing keyword: #{missing_keyword}" if missing_keyword
      return nil if accepts_extra_keywords

      unknown_keyword = (argument_keys - (required_keywords + optional_keywords)).first
      return "unknown keyword: #{unknown_keyword}" if unknown_keyword

      nil
    end

    # A call's questions are counted from its start; one resumed keeps the
    # answers it was given (#answered), and a call it makes of another tool
    # neither sees them nor moves its count.
    # A fresh Hash each time: fibers inherit their parent's storage, and
    # parallel calls mustn't share a count.
    def asking # :nodoc:
      previous = Fiber[ASKING]
      input = Fiber[RESUMING]
      Fiber[RESUMING] = nil
      Fiber[ASKING] = { 'input' => input, 'asked' => 0 }
      yield
    ensure
      Fiber[ASKING] = previous
    end

    # Runs a call again that paused on its questions (#ask), now answered or
    # declined, with +input+, the state Chat saved for it.
    def answered(input, arguments, tool_call:) # :nodoc:
      Fiber[RESUMING] = input
      call(**arguments, tool_call:)
    ensure
      Fiber[RESUMING] = nil
    end

    def execute_accepts_tool_call? # :nodoc:
      method(:execute).parameters.any? do |kind, name|
        name == TOOL_CALL_KEYWORD && KEYWORD_PARAMETER_KINDS.include?(kind)
      end
    end

    def execute_keyword_signature # :nodoc:
      keyword_signature = method(:execute).parameters.reject { |_, name| name == TOOL_CALL_KEYWORD }
      required_keywords = keyword_signature.filter_map { |kind, name| name if kind == :keyreq }
      optional_keywords = keyword_signature.filter_map { |kind, name| name if kind == :key }
      accepts_extra_keywords = keyword_signature.any? { |kind, _| kind == :keyrest }

      [required_keywords, optional_keywords, accepts_extra_keywords]
    end

    def inferred_parameters # :nodoc:
      required_keywords, optional_keywords, = execute_keyword_signature

      (required_keywords + optional_keywords).to_h do |name|
        [name, Parameter.new(name, required: required_keywords.include?(name))]
      end
    end

    class SchemaDefinition # :nodoc:
      def self.from_parameters(parameters, allow_empty: false)
        return nil if parameters.nil? || (parameters.empty? && !allow_empty)

        properties = parameters.to_h do |name, param|
          schema = {
            type: map_type(param.type),
            description: param.description
          }.compact

          schema[:items] = default_items_schema if schema[:type] == 'array'

          [name.to_s, schema]
        end

        required = parameters.select { |_, param| param.required }.keys.map(&:to_s)

        json_schema = {
          type: 'object',
          properties: properties,
          required: required,
          additionalProperties: false,
          strict: true
        }

        new(schema: json_schema)
      end

      def self.map_type(type)
        case type.to_s
        when 'integer', 'int' then 'integer'
        when 'number', 'float', 'double' then 'number'
        when 'boolean' then 'boolean'
        when 'array' then 'array'
        when 'object' then 'object'
        else
          'string'
        end
      end

      def self.default_items_schema
        { type: 'string' }
      end

      def initialize(schema: nil, block: nil)
        @schema = schema
        @block = block
      end

      def present?
        @schema || @block
      end

      def json_schema
        @json_schema ||= RubyLLM::Support::Utils.strip_schema_metadata(
          RubyLLM::Support::Utils.deep_stringify_keys(resolve_schema)
        )
      end

      private

      def resolve_schema
        return resolve_direct_schema(@schema) if @schema
        return build_from_block(&@block) if @block

        nil
      end

      def resolve_direct_schema(schema)
        return extract_schema(schema.to_json_schema) if schema.respond_to?(:to_json_schema)
        return RubyLLM::Support::Utils.deep_dup(schema) if schema.is_a?(Hash)
        if schema.is_a?(Class) && schema.method_defined?(:to_json_schema)
          return extract_schema(schema.new.to_json_schema)
        end

        nil
      end

      def build_from_block(&)
        schema_class = Schematist::Schema.create(&)
        extract_schema(schema_class.new.to_json_schema)
      end

      def extract_schema(schema_hash)
        return nil unless schema_hash.is_a?(Hash)

        schema = schema_hash[:schema] || schema_hash['schema'] || schema_hash
        RubyLLM::Support::Utils.deep_dup(schema)
      end
    end
  end
end
