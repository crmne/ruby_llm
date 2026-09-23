# frozen_string_literal: true

module RubyLLM
  class MCP
    # A prompt an MCP server offers: messages written by the server and
    # filled in with your arguments. Ask a chat with it like a question.
    #
    #   github.prompts                     # => [#<RubyLLM::MCP::Prompt name: "code_review", ...>]
    #   review = github.prompt(:code_review, code: diff)
    #   review.messages                    # => [#<RubyLLM::Message role: :user, ...>]
    #   chat.ask review
    #
    class Prompt
      include Support::Inspectable

      # An argument a prompt takes.
      Argument = Struct.new(:name, :description, :required, keyword_init: true) do
        # Returns whether the prompt needs this argument.
        def required?
          required == true
        end
      end

      # The prompt's name.
      attr_reader :name

      # A human-readable title, or +nil+.
      attr_reader :title

      # What the prompt does, or +nil+.
      attr_reader :description

      # The arguments the prompt takes, as Argument objects.
      attr_reader :arguments

      def initialize(mcp, data, messages: nil) # :nodoc:
        @mcp = mcp
        @name = data['name']
        @title = data['title']
        @description = data['description']
        @arguments = Array(data['arguments']).map do |argument|
          Argument.new(name: argument['name'].to_sym, description: argument['description'],
                       required: argument['required'])
        end
        @messages = messages
      end

      # Returns the prompt's messages as Message objects. A prompt from
      # MCP#prompts has none until you fill it in with MCP#prompt.
      def messages
        @messages || []
      end

      # Asks the server to complete an argument's partial value. Pass one
      # argument to complete and any others that are already filled in.
      # Returns an Array of suggested values.
      #
      #   github.prompts.first.suggest(language: "ru")  # => ["ruby", "rust"]
      #
      def suggest(**arguments)
        @mcp.suggest({ type: 'ref/prompt', name: }, arguments)
      end

      private

      def inspect_attributes
        { name:, arguments: arguments.map(&:name), messages: messages.size.nonzero? }
      end
    end
  end
end
