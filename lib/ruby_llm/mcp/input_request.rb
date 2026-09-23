# frozen_string_literal: true

module RubyLLM
  class MCP
    # A server's request for input from the user while it works on a call,
    # received by MCP.before_input_request callbacks. A form request asks
    # for values; a URL request asks the user to visit a page, such as to
    # connect an account.
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
    # A request no callback answers goes to the model as the tool's error,
    # with the message and any URL, so it can ask the user.
    class InputRequest
      include Support::Inspectable

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

      def initialize(key, params) # :nodoc:
        @key = key
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

      # Accepts the request. A form request takes the values as keywords;
      # a URL request takes none, meaning the user agreed to visit the page.
      def answer(**values)
        @response = { action: 'accept', content: (values.transform_keys(&:to_s) unless url?) }.compact
      end

      # Declines the request.
      def decline
        @response = { action: 'decline' }
      end

      # Returns whether the request has been answered or declined.
      def answered?
        !response.nil?
      end

      private

      def fields_from(schema)
        required = Array(schema['required'])
        schema.fetch('properties', {}).map do |name, property|
          Field.new(name: name.to_sym, type: property['type'], title: property['title'],
                    description: property['description'], required: required.include?(name),
                    choices: choices(property), default: property['default'])
        end
      end

      def choices(property)
        options = property['enum'] || Array(property['oneOf'] || property.dig('items', 'anyOf')).map { |o| o['const'] }
        options unless options.empty?
      end

      def inspect_attributes
        { message:, url:, fields: fields.map(&:name) }
      end
    end
  end
end
