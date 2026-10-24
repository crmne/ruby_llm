# frozen_string_literal: true

module RubyLLM
  module Tools
    # The +tool_search+ tool a chat with deferred tools gives the model when
    # its provider has no tool search of its own. The model searches the
    # deferred tools by what it needs to do, or names them, and the chat
    # sends the definitions of the tools it found with every request after
    # that. See Chat#deferred_tools.
    class Search < Tool # :nodoc:
      DEFAULT_LIMIT = 5
      MAX_LIMIT = 20
      SELECT = 'select:'
      SUMMARY_LENGTH = 200

      spill_to_file false

      def self.tool_name
        'tool_search'
      end

      def self.loaded_names(content)
        names = JSON.parse(content.to_s)['loaded'] if content.to_s.start_with?('{')
        names.is_a?(Array) ? names.map(&:to_s) : []
      rescue JSON::ParserError
        []
      end

      def initialize(tools)
        super()
        @tools = tools
      end

      def description
        'Loads tools you can call in this conversation but whose definitions are not shown yet. Search by what ' \
          'you need to do, in a few words, and the tools that match become callable from your next step on, for ' \
          "the rest of the conversation. Pass #{SELECT}name,other_name to load tools by name. " \
          "Tools you can load: #{@tools.call.keys.join(', ')}."
      end

      def parameters_schema
        {
          'type' => 'object',
          'properties' => {
            'query' => { 'type' => 'string',
                         'description' => "A few words about the task, or #{SELECT} and tool names, comma-separated" },
            'limit' => { 'type' => 'integer', 'description' => "How many tools to load, #{MAX_LIMIT} at most",
                         'default' => DEFAULT_LIMIT, 'minimum' => 1, 'maximum' => MAX_LIMIT }
          },
          'required' => %w[query],
          'additionalProperties' => false
        }
      end

      def execute(query:, limit: DEFAULT_LIMIT)
        tools = @tools.call
        found = matches(tools, query.to_s, limit.to_i.clamp(1, MAX_LIMIT))
        if found.empty?
          { loaded: [], error: "No tools match #{query}. Tools you can load: #{tools.keys.join(', ')}" }
        else
          { loaded: found.map(&:name), tools: found.map { |tool| { name: tool.name, description: summary(tool) } } }
        end
      end

      private

      def matches(tools, query, limit)
        return selected(tools, query.delete_prefix(SELECT)) if query.start_with?(SELECT)

        terms = words(query)
        ranked = tools.values.each_with_index.filter_map do |tool, index|
          score = terms.sum { |term| score(tool, term) }
          [-score, index, tool] if score.positive?
        end
        ranked.sort.first(limit).map(&:last)
      end

      def selected(tools, names)
        names.split(',').filter_map { |name| tools[name.strip.to_sym] }.uniq
      end

      def score(tool, term)
        name_words = words(tool.name)
        return 4 if name_words.include?(term)
        return 2 if tool.name.downcase.include?(term)
        return 1 if words("#{tool.description} #{parameter_names(tool)}").any? { |word| word.start_with?(term) }

        0
      end

      def words(text)
        text.to_s.downcase.scan(/[[:alnum:]]+/)
      end

      def parameter_names(tool)
        properties = tool.parameters_schema.to_h.transform_keys(&:to_s)['properties']
        properties.is_a?(Hash) ? properties.keys.join(' ') : ''
      end

      def summary(tool)
        text = tool.description.to_s.strip
        text.length > SUMMARY_LENGTH ? "#{text[0, SUMMARY_LENGTH - 3].rstrip}..." : text
      end
    end
  end
end
