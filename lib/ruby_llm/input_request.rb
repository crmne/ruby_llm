# frozen_string_literal: true

module RubyLLM
  # A request for input from the user while a tool works on a call: an MCP
  # server's question, received by MCP.before_input_request callbacks, or a
  # tool's own, from Tool#ask. A form request asks for values; a URL request
  # asks the user to visit a page, such as to connect an account.
  #
  #   before_input_request do |request|
  #     if request.url?
  #       system "open", request.url
  #       request.answer
  #     else
  #       request.answer(environment: "staging")
  #     end
  #   end
  #
  # In a chat, a request no callback answers pauses the tool call until
  # Chat#answer or Chat#decline settles it; see Chat#pending_inputs.
  class InputRequest
    include Support::Inspectable

    # What the user said to a tool's own question (Tool#ask): accepted with
    # values, or declined. Read a value with #[].
    class Answer
      def initialize(response) # :nodoc:
        @response = response.to_h.transform_keys(&:to_s)
      end

      def accepted?
        @response['action'] == 'accept'
      end

      def declined?
        !accepted?
      end

      # The value given for the field +name+, or +nil+.
      def [](name)
        @response.fetch('content', nil).to_h.transform_keys(&:to_s)[name.to_s]
      end

      def to_h
        @response.fetch('content', nil).to_h.transform_keys(&:to_sym)
      end
    end

    # A tool's own question (Tool#ask), the +index+th it asks in its call:
    # a form for +fields+ (name to a JSON Schema property, plus
    # <tt>required: true</tt>), or, given +url:+, a page to visit.
    def self.ask(index, message, url: nil, fields: {}) # :nodoc:
      params = if url
                 { 'mode' => 'url', 'message' => message.to_s, 'url' => url.to_s }
               else
                 { 'mode' => 'form', 'message' => message.to_s, 'requestedSchema' => schema_for(fields) }
               end
      new("ask_#{index}", params)
    end

    def self.schema_for(fields) # :nodoc:
      properties = fields.to_h { |name, property| [name.to_s, property.to_h.except(:required).transform_keys(&:to_s)] }
      required = fields.select { |_, property| property.to_h[:required] }.keys.map(&:to_s)
      { 'type' => 'object', 'properties' => properties, 'required' => required }
    end

    # A value a form request asks for.
    Field = Struct.new(:name, :type, :title, :description, :required, :choices, :default, keyword_init: true) do
      # Returns whether the server needs this value.
      def required?
        required == true
      end
    end

    # Why the server needs the input.
    attr_reader :message

    # The page a URL request asks the user to visit, or +nil+.
    attr_reader :url

    # The values a form request asks for, as Field objects.
    attr_reader :fields

    attr_reader :key, :response # :nodoc:

    # The ToolCall paused on this request, when it came from a chat.
    attr_reader :tool_call

    def self.from_h(data, tool_call: nil) # :nodoc:
      new(data['key'], data['params'], response: data['response'], tool_call:)
    end

    def initialize(key, params, response: nil, tool_call: nil) # :nodoc:
      @key = key
      @params = params
      @response = response
      @tool_call = tool_call
      @message = params['message']
      @url = params['url'] if params['mode'] == 'url'
      @fields = fields_from(params['requestedSchema'] || {})
    end

    # Returns whether the server asks the user to visit #url.
    def url?
      !url.nil?
    end

    # Returns whether the server asks for #fields.
    def form?
      !url?
    end

    # Accepts the request. A form request takes the values as keywords,
    # and the fields you leave out take the defaults the server gave
    # them; a URL request takes none, meaning the user agreed to visit
    # the page.
    def answer(**values)
      @response = { action: 'accept', content: (with_defaults(values) unless url?) }.compact
    end

    # Declines the request.
    def decline
      @response = { action: 'decline' }
    end

    # Returns whether the request has been answered or declined.
    def answered?
      !response.nil?
    end

    def to_h # :nodoc:
      { 'key' => key, 'params' => @params, 'response' => response&.transform_keys(&:to_s) }.compact
    end

    private

    def with_defaults(values)
      fields.reject { |field| field.default.nil? }.to_h { |field| [field.name, field.default] }
            .merge(values).transform_keys(&:to_s)
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
      { message:, url:, fields: fields.map(&:name) }
    end
  end
end
