# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Session management for agent conversations
    #
    # Sessions track conversation state and allow resuming
    # previous conversations. They can be persisted and restored.
    #
    # @example Resume a session
    #   client = Client.new
    #   result = client.query("Start a task")
    #
    #   # Later...
    #   client.resume(result.session_id)
    #   client.query("Continue the task")
    #
    # @example With Session object
    #   session = Session.new(id: 'abc123')
    #   client = Client.new
    #   client.resume(session.id)
    class Session
      attr_reader :id, :history, :created_at, :metadata

      # @param id [String] Session identifier
      # @param history [Array<Message>] Conversation history
      # @param metadata [Hash] Additional session data
      def initialize(id:, history: [], metadata: {})
        @id = id
        @history = history
        @metadata = metadata
        @created_at = metadata[:created_at] || Time.now
      end

      # Get the last message in the session
      #
      # @return [Message, nil]
      def last_message
        history.last
      end

      # Get the last result message
      #
      # @return [Message, nil]
      def last_result
        history.reverse.find(&:result?)
      end

      # Get all assistant messages
      #
      # @return [Array<Message>]
      def assistant_messages
        history.select(&:assistant?)
      end

      # Get all user messages
      #
      # @return [Array<Message>]
      def user_messages
        history.select(&:user?)
      end

      # Get all tool uses
      #
      # @return [Array<Message>]
      def tool_uses
        history.select(&:tool_use?)
      end

      # Get total cost in USD
      #
      # @return [Float]
      def total_cost_usd
        history.select(&:result?).sum { |m| m.cost_usd || 0 }
      end

      # Get total input tokens
      #
      # @return [Integer]
      def total_input_tokens
        history.select(&:result?).sum { |m| m.input_tokens || 0 }
      end

      # Get total output tokens
      #
      # @return [Integer]
      def total_output_tokens
        history.select(&:result?).sum { |m| m.output_tokens || 0 }
      end

      # Get number of turns
      #
      # @return [Integer]
      def turns
        history.count(&:result?)
      end

      # Check if session is empty
      #
      # @return [Boolean]
      def empty?
        history.empty?
      end

      # Get session duration
      #
      # @return [Float] Duration in seconds
      def duration
        return 0 if history.empty?

        # Estimate from message timestamps if available
        last_time = history.last&.data&.dig(:timestamp)
        return 0 unless last_time && created_at

        Time.parse(last_time).to_f - created_at.to_f
      rescue ArgumentError
        0
      end

      # Convert to hash for serialization
      #
      # @return [Hash]
      def to_h
        {
          id: id,
          created_at: created_at.iso8601,
          turns: turns,
          total_cost_usd: total_cost_usd,
          total_input_tokens: total_input_tokens,
          total_output_tokens: total_output_tokens,
          message_count: history.size,
          metadata: metadata
        }
      end

      # Create from stored data
      #
      # @param data [Hash] Serialized session data
      # @return [Session]
      def self.from_h(data)
        new(
          id: data[:id] || data['id'],
          history: (data[:history] || data['history'] || []).map { |h| Message.new(h) },
          metadata: (data[:metadata] || data['metadata'] || {}).merge(
            created_at: parse_time(data[:created_at] || data['created_at'])
          )
        )
      end

      # Parse time from string or return Time object
      #
      # @param value [String, Time, nil]
      # @return [Time, nil]
      def self.parse_time(value)
        case value
        when Time then value
        when String then Time.parse(value)
        else nil
        end
      rescue ArgumentError
        nil
      end
    end

    # Session store for persisting sessions
    #
    # @example In-memory store
    #   store = SessionStore.new
    #   store.save(session)
    #   loaded = store.load('abc123')
    #
    # @example File-based store
    #   store = SessionStore.new(path: '~/.claude/sessions')
    #   store.save(session)
    class SessionStore
      attr_reader :path

      # @param path [String, nil] Directory path for file storage
      def initialize(path: nil)
        @path = path ? File.expand_path(path) : nil
        @memory = {}

        setup_directory if @path
      end

      # Save a session
      #
      # @param session [Session] Session to save
      # @return [void]
      def save(session)
        @memory[session.id] = session

        if @path
          file = File.join(@path, "#{session.id}.json")
          File.write(file, JSON.pretty_generate(session.to_h))
        end
      end

      # Load a session by ID
      #
      # @param id [String] Session ID
      # @return [Session, nil]
      def load(id)
        return @memory[id] if @memory[id]

        if @path
          file = File.join(@path, "#{id}.json")
          return nil unless File.exist?(file)

          data = JSON.parse(File.read(file), symbolize_names: true)
          Session.from_h(data)
        end
      end

      # Delete a session
      #
      # @param id [String] Session ID
      # @return [void]
      def delete(id)
        @memory.delete(id)

        if @path
          file = File.join(@path, "#{id}.json")
          File.delete(file) if File.exist?(file)
        end
      end

      # List all session IDs
      #
      # @return [Array<String>]
      def list
        ids = @memory.keys

        if @path
          Dir.glob(File.join(@path, '*.json')).each do |file|
            id = File.basename(file, '.json')
            ids << id unless ids.include?(id)
          end
        end

        ids.uniq
      end

      # Check if a session exists
      #
      # @param id [String] Session ID
      # @return [Boolean]
      def exist?(id)
        return true if @memory[id]

        if @path
          File.exist?(File.join(@path, "#{id}.json"))
        else
          false
        end
      end

      private

      def setup_directory
        FileUtils.mkdir_p(@path) unless File.exist?(@path)
      end
    end
  end
end
