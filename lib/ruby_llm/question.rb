# frozen_string_literal: true

require 'securerandom'

module RubyLLM
  # A question a tool call waits on until a person answers it: the
  # approval a tool declared with Tool.requires_approval asks before it
  # runs, a question the tool asks itself with Tool#ask, or one an MCP
  # server asks while it works on the call. Chat#pending_questions returns
  # the questions a chat waits on.
  #
  #   question = chat.pending_questions.first
  #   question.message               # => "Window or aisle?"
  #   question.fields.first.choices  # => ["window", "aisle"]
  #   question.answer "window"
  #   chat.complete
  #
  # An approval asks whether its call may run, so it is answered yes or no:
  #
  #   question.approval?      # => true
  #   question.tool_call.name # => "issue_refund"
  #   question.approve        # or question.deny
  #
  # A server can also ask the person to visit a page, such as to connect an
  # account: #url? is +true+, and answering says they agreed to go. Before
  # a server's question reaches the chat, MCP.before_input_request
  # callbacks can answer it.
  class Question
    include Support::Inspectable

    ACCEPTED = { 'action' => 'accept' }.freeze # :nodoc:
    DECLINED = { 'action' => 'decline' }.freeze # :nodoc:
    BOOLEANS = { 'true' => true, '1' => true, 'yes' => true, 'on' => true,
                 'false' => false, '0' => false, 'no' => false, 'off' => false }.freeze
    TYPES = { 'integer' => 'a whole number', 'number' => 'a number', 'boolean' => 'true or false' }.freeze
    private_constant :BOOLEANS, :TYPES

    # A value a question asks for.
    Field = Struct.new(:name, :type, :title, :description, :required, :choices, :default, keyword_init: true) do
      # Returns whether the question needs this value.
      def required?
        required == true
      end
    end

    # The question, or +nil+ for an approval.
    attr_reader :message

    # The page the question asks the person to visit, or +nil+.
    attr_reader :url

    # The values the question asks for, as Field objects: one for a question
    # Tool#ask asks without a block, none for an approval or a page to visit.
    attr_reader :fields

    # The ToolCall that waits on the question, when it came from a chat.
    attr_reader :tool_call

    attr_reader :key, :response # :nodoc:

    class << self
      # Returns the question Tool#ask asks as its +index+th: one that takes
      # free text or one of +choices+, a visit to +url+, or the fields
      # +schema+ describes.
      def asked(index, message, choices: nil, url: nil, schema: nil) # :nodoc:
        params = { 'mode' => url ? 'url' : 'form', 'message' => message.to_s }
        if url
          params['url'] = url.to_s
        else
          params['requestedSchema'] = schema || answer_schema(choices)
        end
        new("ask_#{index}", params)
      end

      # Returns the approval +chat+ waits on before it runs +tool_call+.
      def approval(tool_call, chat:) # :nodoc:
        new('approval', {}, id: tool_call.id, tool_call:, chat:, approval: true)
      end

      def from_h(data, tool_call: nil, chat: nil) # :nodoc:
        new(data['key'], data['params'], id: data['id'] || data['key'], response: data['response'], tool_call:, chat:)
      end

      # Returns the call +decision+ approves or denies: the ToolCall of an
      # approval, or +decision+ itself, such as a ToolCall or its id.
      # Raises ArgumentError for any other Question, which takes +instead+.
      def decided_call(decision, instead) # :nodoc:
        return decision unless decision.is_a?(Question)
        raise ArgumentError, "This question is not an approval: #{instead} it instead" unless decision.approval?

        decision.tool_call
      end

      private

      def answer_schema(choices)
        raise ArgumentError, 'choices: needs at least one choice' if choices && Array(choices).empty?

        answer = { 'type' => 'string', 'enum' => choices&.map(&:to_s) }.compact
        { 'type' => 'object', 'properties' => { 'answer' => answer }, 'required' => ['answer'] }
      end
    end

    def initialize(key, params, id: SecureRandom.hex(8), response: nil, tool_call: nil, chat: nil, # :nodoc:
                   approval: false)
      @key = key
      @params = params
      @nonce = id
      @response = response
      @tool_call = tool_call
      @chat = chat
      @approval = approval
      @message = params['message']
      @url = params['url'] if params['mode'] == 'url'
      @fields = fields_from(params['requestedSchema'] || {})
    end

    # Returns a String that identifies the question among those of its
    # chat. Chat#answer and the other methods that take a question take its
    # id too, so a form can send it. An approval has its tool call's id.
    def id
      return @nonce if tool_call.nil? || approval?

      "#{tool_call.id}/#{@nonce}"
    end

    # Returns whether the question asks whether its call may run: the
    # approval of a tool declared with Tool.requires_approval. Answer it
    # with #approve or #deny.
    def approval?
      @approval
    end

    # Returns whether the question asks the person to visit #url.
    def url?
      !url.nil?
    end

    # Returns whether the question asks for #fields.
    def form?
      !url? && !approval?
    end

    # Returns whether the question has been answered or declined.
    def answered?
      !response.nil?
    end

    # Answers the question and returns +self+. A question with one field,
    # as Tool#ask asks without a block, takes its value. One with several
    # takes them by name, as keywords or a Hash, and a field left out takes
    # the default the question gives it. An approval or a page to visit
    # takes no value: answering an approval approves its call, and
    # answering a page says the person agreed to visit it.
    #
    #   question.answer "window"
    #   question.answer environment: "staging", reason: "Release 2.2"
    #
    # A question from a chat records the answer there, as Chat#answer
    # does, and the next Chat#complete carries the call on.
    #
    # Strings become the integers, numbers, and booleans the fields ask
    # for, the way a form sends them, and a blank String counts as left
    # out. Raises ArgumentError for a value the question does not ask for,
    # a choice it does not offer, a value of the wrong type, or a required
    # value left out.
    def answer(value = nil, **values)
      if @chat
        @chat.answer(self, value, **values)
      else
        respond(response_to(value, values))
      end
      self
    end

    # Declines the question and returns +self+. Declining an approval
    # denies its call. A question from a chat records it there, as
    # Chat#decline does.
    def decline
      if @chat
        @chat.decline(self)
      else
        respond(DECLINED)
      end
      self
    end

    # Approves the call an approval asks about, as Chat#approve does, and
    # returns +self+. With <tt>remember: true</tt>, later calls to the same
    # tool run without asking for the rest of the chat.
    #
    # Raises ArgumentError for a question that is not an approval.
    def approve(remember: false)
      self.class.decided_call(self, 'answer')
      @chat ? @chat.approve(self, remember:) : respond(ACCEPTED)
      self
    end

    # Denies the call an approval asks about, as Chat#deny does, and
    # returns +self+. The model gets a result saying the person denied it.
    #
    # Raises ArgumentError for a question that is not an approval.
    def deny
      self.class.decided_call(self, 'decline')
      @chat ? @chat.deny(self) : respond(DECLINED)
      self
    end

    # Returns the response an answer of +value+ and +values+ makes, as
    # #answer describes, raising ArgumentError for one it can't take.
    def response_to(value, values) # :nodoc:
      return response_without(value, values) unless form?

      given = given_values(value, values)
      unknown = given.keys - fields.map { |field| field.name.to_s }
      raise ArgumentError, "The question does not ask for #{unknown.join(' or ')}" if unknown.any?

      ACCEPTED.merge('content' => content_from(given))
    end

    # Returns what Tool#ask returns for the question's answer: +nil+ when
    # it was declined, +true+ for a page to visit, the values by name when
    # +by_name+ (a block declared the fields), or else the one value.
    def asked_answer(by_name) # :nodoc:
      return unless response && response['action'] == 'accept'
      return true if url?

      content = response['content'].to_h
      by_name ? content.transform_keys(&:to_sym) : content['answer']
    end

    # Records +response+ as the question's own, and returns +self+.
    def respond(response) # :nodoc:
      @response = response
      self
    end

    # Returns +input+, the state the question's call paused on, with
    # +response+ as its answer while it still waits for one.
    def answered_input(input, response) # :nodoc:
      requests = input['requests'].map do |data|
        waiting = data['response'].nil? && self.class.from_h(data, tool_call:).id == id
        waiting ? data.merge('response' => response) : data
      end
      input.merge('requests' => requests)
    end

    def to_h # :nodoc:
      { 'id' => @nonce, 'key' => key, 'params' => @params, 'response' => response }.compact
    end

    private

    def response_without(value, values)
      return ACCEPTED if value.nil? && values.empty?

      raise ArgumentError, "#{approval? ? 'An approval' : 'A page to visit'} takes no answer"
    end

    def given_values(value, values)
      given = case value
              when nil, Hash then value.to_h
              else
                unless fields.one?
                  raise ArgumentError, "The question asks for #{fields.map(&:name).join(' and ')}: give each by name"
                end

                { fields.first.name => value }
              end
      given.merge(values).transform_keys(&:to_s)
    end

    def content_from(given)
      fields.each_with_object({}) do |field, content|
        answer = value_for(field, given[field.name.to_s])
        answer = field.default if answer.nil?
        raise ArgumentError, "#{label(field)} needs an answer" if answer.nil? && field.required?

        content[field.name.to_s] = answer unless answer.nil?
      end
    end

    def value_for(field, value)
      value = Array(value).reject { |item| blank?(item) } if field.type == 'array'
      return if blank?(value)

      typed(field, value).tap { |typed| offered(field, typed) }
    end

    def typed(field, value)
      return value unless value.is_a?(String)

      case field.type
      when 'integer' then Integer(value, 10)
      when 'number' then Float(value)
      when 'boolean' then BOOLEANS.fetch(value.strip.downcase) { raise ArgumentError }
      else value
      end
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{label(field)} takes #{TYPES.fetch(field.type)}"
    end

    def offered(field, value)
      return unless field.choices

      Array(value).each do |choice|
        next if field.choices.include?(choice)

        raise ArgumentError, "#{choice.inspect} is not one of the choices: #{field.choices.join(', ')}"
      end
    end

    def blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?) || (value.is_a?(String) && value.strip.empty?)
    end

    def label(field)
      field.title || (fields.one? ? 'The question' : field.name.to_s)
    end

    def fields_from(schema)
      required = Array(schema['required'])
      schema.fetch('properties', {}).map do |name, property|
        Field.new(name: name.to_sym, type: property['type'], title: property['title'],
                  description: property['description'], required: required.include?(name),
                  choices: choices(property), default: property['default'])
      end
    end

    def choices(property)
      options = property['enum'] || property.dig('items', 'enum') ||
                Array(property['oneOf'] || property.dig('items', 'anyOf')).map { |o| o['const'] }
      options unless options.empty?
    end

    def inspect_attributes
      { id:, message:, url:, approval: (true if approval?), tool_call: (tool_call.name if approval?),
        fields: fields.map(&:name) }
    end
  end
end
